# Meal text parser: grammar and rules

Phase 3 design. Phase 4 builds this. Nothing here is code yet.

This document says exactly how the text a user types or dictates into the food entry box becomes lines of food, with amounts and nutrients. It is written so each rule can be tested. The worked examples in [section 11](#11-worked-examples) are meant to become Phase 4 unit tests as they stand.

Everything was checked against the bundled reference data (`assets/food/usda.sqlite.gz`, data version 2026-10-29) and the FNDDS source file the build uses. A throwaway prototype of these rules, kept outside the repo, computed every number in the examples.

## Contents

1. [Overview](#1-overview)
2. [Splitting text into items](#2-splitting-text-into-items)
3. [Quantities](#3-quantities)
4. [Units, sizes and grams](#4-units-sizes-and-grams)
5. [Matching an item to a food](#5-matching-an-item-to-a-food)
6. [Aliases and saved meals](#6-aliases-and-saved-meals)
7. [Learning from corrections](#7-learning-from-corrections)
8. [Line states and the correction sheet](#8-line-states-and-the-correction-sheet)
9. [Live re-parsing](#9-live-re-parsing)
10. [Grammar and token lists](#10-grammar-and-token-lists)
11. [Worked examples](#11-worked-examples)
12. [Limits and speed](#12-limits-and-speed)
13. [Changes needed outside this document](#13-changes-needed-outside-this-document)
14. [Decisions and open questions for Bart](#14-decisions-and-open-questions-for-bart)
    - [14.1 Decided in review](#141-decided-in-review)
    - [14.2 Open questions](#142-open-questions)
    - [14.3 Clarified during the build](#143-clarified-during-the-build)

## 1. Overview

The text box is the source of truth. Every time the text changes, the parser runs these steps in order:

1. **Clean up characters** (unicode fractions, `&`, `w/`, curly quotes).
2. **Split into chunks** at hard separators: new line, comma, semicolon, `+`, `plus`, end of sentence.
3. **Mark protected phrases** inside each chunk: a short built-in list of food names such as "half and half", and the user's own names of two or more words (2.3).
4. **Join number phrases** that contain "and": "one and a half", "a cup and a half".
5. **Split into pieces** at the remaining soft separators: "and", "&", "with", "w/".
6. **Split pieces into items** where a new quantity starts after food words (this handles dictation without commas).
7. **Read each item**: quantity, multiplier, size, unit, food words.
8. **Find the food**: alias or saved meal, then a learned correction, then ranked search over the user's foods and the USDA data.
9. **Work out grams** from the food's own portions.
10. **Give the line a state**: matched, guess, amount assumed, not found, or alias or saved meal.

Typed lines are not the only lines. A food added without typing (barcode scan, a recent or frequent chip, a saved meal chip, the stored entries of a meal being edited) becomes an **added line** that lives outside the text box ([section 9.3](#93-added-lines)). The parser only reads the text. The app never writes food names into the text box.

Rules that apply throughout:

- **Deterministic.** The same text, user data (foods, history, learned matches, aliases, saved meals) and reference data always give the same lines. Every ranking ends in a tie-break on the food reference text, so there are no ties left to chance.
- **On the device only.** No network, no AI model.
- **English, decimal point.** See [section 12](#12-limits-and-speed).
- **Food references** are `usda:<fdc id>` or `local:<id>`. Nutrient ids are USDA ids.

## 2. Splitting text into items

### 2.1 Character clean-up

Before anything else:

| Input | Becomes | Example |
|---|---|---|
| Unicode fraction characters ½ ⅓ ⅔ ¼ ¾ ⅕ ⅖ ⅗ ⅘ ⅙ ⅚ ⅐ ⅛ ⅜ ⅝ ⅞ ⅑ ⅒ | the same fraction written with `/`, with a space before it if a digit comes first | `1½` becomes `1 1/2` |
| Fraction slash (U+2044) | `/` | `1⁄2` becomes `1/2` |
| `&` | ` and ` | `pb&j` becomes `pb and j` |
| `w/` | ` with ` | `coffee w/ milk` |
| `w/o` | ` without ` | |
| `<number> percent` | `<number>%` | `2 percent milk` becomes `2% milk` |
| Curly quotes, and apostrophes both straight and curly | removed | `mom's` becomes `moms` |
| A hyphen between two letters | a space | `half-and-half`, `extra-large`, `hard-boiled`, `twenty-five` |
| A hyphen between a letter and a following digit | removed | `V-8` becomes `V8` |
| A hyphen between a digit and a following letter | a space | `2-percent` becomes `2 percent` |
| A hyphen with a digit on both sides | kept, for the quantity rules in section 3 | `2-3` (a range), `1-1/2` (a mixed number) |
| A combining mark (an accent stored as its own character) | kept with the letter before it; it never splits a word | `café` typed with a combining accent stays one word |
| Any other character that is not a letter, digit, space, `,` `;` `.` `/` `%` `+` `-` `~` `×` or new line | a space | `!!!` becomes nothing |

Because `&`, `w/` and `w/o` are replaced here, the later steps and the grammar in section 10 only ever see the words "and", "with" and "without".

The `<number> percent` row is applied after the hyphen rows, so `2-percent milk` becomes `2 percent milk` and then `2% milk`, not a quantity of 2.

**Tokens with no letter or digit.** A token made only of punctuation or symbols, such as `-`, `/`, `%` or `×` on its own, is ignored once the quantity rules in section 3 have had their chance to use it (in a range or a multiplier, for example). It never becomes a food word. `2 eggs - coffee` is read as if the hyphen were not there.

**Words that contain digits.**

- A word that starts with letters and contains digits is one word: `V8`, `G2`, `B12`. There are 32 bundled food names with such words ("Gatorade G2", "vitamins B6 and B12"). The exception is `x` or `×` followed by digits, which is always a multiplier: `x3` is `x 3`.
- A number in any form (whole, decimal or fraction) touching letters after it is split into the number and a word: `100g` is `100 g`, `2c` is `2 c`, `1T` is `1 T`, `1/2c` is `1/2 c`, `2x` is `2 x`, `2eggs` is `2 eggs`.
- The exception is a word that is itself an entry in the synonym list (5.3), the built-in protected list (2.3), or the user's own names: it stays whole. `7up` stays one word because it is a synonym entry. For the user's names this holds only when the whole name is that one word (a product named "7up"), not for a word inside a longer name (2.3), and a cached product's name counts only once it has been logged, as in 2.3. Synonym entries such as `7up` are not affected by that condition.

Case is kept until the units step, because `T` and `t` mean different units. All other comparisons ignore case.

### 2.2 Hard separators

These always end an item:

- new line
- `,` and `;`
- `+` and the word `plus`
- end of sentence: a `.` followed by a space or the end of the text. There are two exceptions, where the period belongs to the word before it:
  - that word is a unit spelling read as a unit there, because it follows a quantity or a size word or comes before `of` (`2 oz.`, `1 tbsp.`), or it is the abbreviation `fl` (`fl. oz.`). A unit spelling used as a food word does not count, so `I ate a candy bar. Coffee with milk.` is two sentences;
  - that word is one of the title abbreviations `dr`, `mr`, `mrs`, `ms`, `st`, `jr`, `sr`, `vs`, so `1 can Dr. Pepper` stays one item.

  A `.` between or before digits is a decimal point.

A comma is never a decimal point (see [section 12](#12-limits-and-speed)).

### 2.3 Protected phrases

A protected phrase is a food name whose words are kept together. Its words are never split, never read as quantities and never dropped as filler (2.6 rule 1); the user's own names are also never read as sizes or units (item 2 below). Protected phrases are found first, longest match first, scanning left to right. A phrase protects only text that contains the whole phrase. Phrases are compared ignoring case and accents, the same folding as the name key in 6.1, so `cafe and croissant` is kept whole when the user has a food named "Café and croissant".

The protected list is:

1. **The built-in list**, kept in code with a test for each entry. Each one is a food in the bundled data, or would split into the wrong foods:

   `half and half`, `mac and cheese`, `mac n cheese`, `macaroni and cheese`, `peanut butter and jelly`, `pb and j`, `pb and jelly`, `almond butter and jelly`, `sweet and sour`, `sour cream and onion`, `peas and carrots`, `beans and rice`, `rice and beans`, `pork and beans`, `beans and franks`, `beef and broccoli`, `biscuits and gravy`, `gin and tonic`, `vodka and tonic`, `rum and cola`, `rum and coke`, `7 up`

   One more phrase is protected only so that its `a` is never read as a quantity: `a la` (as in "chicken a la king", "pie a la mode").

2. **The user's own names of two or more words**: names of the user's foods, recipes and cached Open Food Facts products, saved meal names, and alias phrases. Each is protected in full, whatever words it contains: against splitting, against quantity, size and unit reading, against filler removal, and against the negation cut (5.2 step 3). A cached Open Food Facts product's name counts only once the user has logged that product at least once, the same condition sort key 2 uses in 5.4; custom foods, recipes, alias phrases and saved meal names always count. So a scanned, never logged product "Large eggs" does not change what `2 large eggs` means (example 38) until it has been logged. With a logged cached product "Big Mac", `big mac` gives the food words "big mac", not a large "mac"; "Thin Mints" and "Mini Wheats" work the same way. A saved meal called "eggs and toast" stays whole, and with an alias "my oatmeal", the "my" in `I had my oatmeal` is kept.

   A one-word name needs no protection and gets none, so a recipe named "Bowl" never stops `1 bowl of rice` reading "bowl" as a unit. The one exception is the 2.1 rule that keeps a one-word name containing digits whole (a product named "7up").

   Each name goes through the clean-up in 2.1 before it becomes a protected phrase, so a product named "Coca-Cola 330ml" becomes "coca cola 330 ml". It protects only text that contains the whole name, so it does not stop `330ml milk` being read as 330 ml of milk.

Why a short hand-made list and not one built from the data: the bundled descriptions contain 2,610 names with " and " and 523 different "word and word" pairs, but the most common are "lean and fat" (781 times), "meat and skin" (149) and "solids and liquids" (114), and the list also holds pairs such as "egg and cheese" (from restaurant sandwiches) and "beef and rice". A list built from the data would stop "eggs and cheese" or "beef and rice" from splitting in ways nobody could predict.

Why not "with": 2,708 descriptions contain " with ", but in the USDA style "with" is a qualifier after a comma ("Burrito, with beans and rice, cheese"). There is no FNDDS dish called "chicken with broccoli" (the only matches are "a la king" dishes), and no "coffee with milk". So no built-in phrase contains "with".

### 2.4 Number phrases that contain "and"

These are joined into one quantity before soft separators are applied. "and" inside them is not a separator.

| Pattern | Value | Example |
|---|---|---|
| whole number, `and`, fraction | sum | `1 and 1/2`, `one and a half`, `two and a quarter`, `1 and three quarters` |
| unit, `and a half` (or `and one half`) | the quantity before the unit, or 1 if none, plus 0.5 | `a cup and a half` = 1.5 cup, `2 cups and a half` = 2.5 cup |

The fraction after `and` must be less than 1: a written fraction (`1/2`), a unicode fraction, or one of the fraction phrases in [section 3](#3-quantities). `2 eggs and 3 slices toast` is not a number phrase, because 3 is not a fraction.

A size word between the number and the unit does not stop the join: `2 large cups and a half milk` is read like `2 cups and a half milk`.

### 2.5 Soft separators: "and" and "with"

After protected phrases and number phrases are marked, **every remaining `and` and `with` splits the chunk into pieces** (including those that came from `&` and `w/`). There is no other exception.

- A quantity after the separator simply becomes the next item's quantity: `coffee with 2 tbsp half and half` gives "coffee" and "2 tbsp half and half".
- With no quantity after it, the next item has no amount and gets the default amount ([section 4.6](#46-default-amount)): `coffee with milk` gives "coffee" and "milk", both marked amount assumed.
- Empty pieces are dropped: `eggs, and toast` gives two items, not three.

The alternative reading, keeping "chicken and rice" whole because FNDDS has a dish called "Chicken or turkey and rice", is listed as [open question 1](#142-open-questions).

### 2.6 Splitting a piece into items (dictation)

Phone dictation often leaves out commas: `two eggs two slices of sourdough toast one tablespoon of butter`. Inside a piece, read the tokens left to right:

1. An item has **food words** once it has at least one word that is not a filler word ([section 10](#10-grammar-and-token-lists)). "I had" alone is not food words. Filler words before the first food word are dropped from the food words whether or not an amount was typed: `I had coffee` and `I had 1 coffee` both give the food words "coffee". Words inside a protected phrase are never filler (2.3). So when the user has an alias, saved meal or food named "my oatmeal", `I had my oatmeal`, `I had 1 my oatmeal` and `2 my oatmeal` all give "my oatmeal", and with "usual breakfast", `I had usual breakfast` gives "usual breakfast". Without such a name, `my oatmeal` gives "oatmeal".
2. When a **quantity** (digits, a number word, `dozen`, or a fraction phrase) appears after the current item already has food words, it is the item's **amount after the food** only when both of these hold:
   - the item has no amount yet;
   - the quantity is followed by a unit (and that unit is not followed by `of`), or nothing follows it in the piece except a trailing multiplier.

   Then the item ends after that amount. In every other case the item ends and **a new item starts at the quantity**. Examples:
   - `chicken 200g rice 1 cup` gives "chicken, 200 g" and "rice, 1 cup";
   - `black coffee two eggs and toast` gives "black coffee", "two eggs" and "toast", because "two" has no unit and is followed by "eggs";
   - `2 eggs 2 toast` gives "2 eggs" and "2 toast", because "2 eggs" already has an amount.

   **Words after an amount typed after the food stay with the item**: `chicken breast 6 oz grilled` is one item, "chicken breast grilled", 6 oz; `rice 1 cup cooked` is one item. Only a quantity, or `a`/`an`, starts a new item after that. If those trailing words are followed by a quantity that would be their own amount after the food (the test above), they leave with it as a new item: `chicken 200g rice 1 cup` still gives "chicken, 200 g" and "rice, 1 cup", and `chicken 200g rice 1 cup cooked` gives "chicken, 200 g" and "rice cooked, 1 cup". The cost: `chicken 200g rice`, with no amount for the rice, is one item, "chicken rice", 200 g. A comma fixes it.
3. **A second quantity before any food word** is part of the food name, together with a unit spelling right after it. `2 slices 12 grain bread` is 2 slices of "12 grain bread". Two exceptions:
   - a number right after a multiplier is part of the amount: in `2x 100g chicken breast` the 100 g is the amount;
   - **compound amounts**: when the second quantity has a unit of the same kind as the first (mass and mass, or volume and volume), the two add up, expressed in the first unit. `1 lb 4 oz steak` is 1.25 lb (567 g); `1 cup 2 tbsp milk` is 1.125 cup. "oz" counts as mass here. More amounts of the same kind can follow and add the same way: `1 cup 2 tbsp 1 tsp`. Each added amount must be a single plain number (digits, a decimal or a fraction) followed by a unit; word numbers are not added, so `one cup two tablespoons milk` is not a compound amount. Household and count units never add. Mixed kinds (`1 cup 4 oz milk`) do not add; the second amount becomes part of the food name as above.
4. `x2` or `× 2` after food words is a multiplier of the current item, never a new item: `eggs x3`, `2 eggs x3` (6 eggs). So is a number directly followed by `x` at the end of the item: `eggs 2x` is read like `eggs x2` (3.2).
5. **`a` and `an`.**
   - First, phrases that start with "a" are matched as a whole, longest first, before "a" is read on its own: the quantity phrases `a couple of`, `a couple`, `a dozen`, `a half`, `a quarter`, `a third`, the vague phrases `a bit of`, `a bit`, `a little`, `a few`, and the protected phrase `a la`. So `a couple of eggs` is 2 and `a few almonds` has no quantity.
   - Otherwise, when only filler words come before them in the item, they are the quantity 1. This reading wins over filler: `I had a banana` is 1 banana.
   - After food words they always start a new item, with quantity 1: `two eggs a banana` gives "two eggs" and "a banana".
   - When nothing else is in the item, a lone `a` or `an` is not an amount, and the item gives no line (8.1). So `vitamin a` gives one item, "vitamin", and no second line.
   - Inside `a la` they are food words (2.3).

Foods typed with no separator and no quantity between them stay one item: `eggs toast` is one item and will be a guess at best. This is a stated limit.

### 2.7 The brief's example, step by step

Input: `2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half`

| Step | Result |
|---|---|
| Hard separators (commas) | `2 eggs` / `2 slices sourdough toast` / `1 tbsp butter` / `coffee with 2 tbsp half and half` |
| Protected phrases | in the last chunk, `half and half` is protected |
| Number phrases | none |
| Soft separators | the last chunk splits at `with` into `coffee` and `2 tbsp half and half`. The `and` inside `half and half` is protected. |
| Items | 5 items: `2 eggs`, `2 slices sourdough toast`, `1 tbsp butter`, `coffee`, `2 tbsp half and half` |
| Read items | 2, no unit, "eggs" / 2 slice "sourdough toast" / 1 tbsp "butter" / no amount, "coffee" / 2 tbsp "half and half" |

The dictated version `two eggs two slices of sourdough toast one tablespoon of butter and coffee with two tablespoons of half and half` gives the same 5 items (example 2 in section 11): "two" after "eggs" starts a new item, "one" after "toast" starts a new item, and "and" and "with" split the rest.

## 3. Quantities

### 3.1 Accepted forms

| Form | Examples | Value |
|---|---|---|
| Whole number | `2`, `12` | 2, 12 |
| Decimal | `1.5`, `0.5`, `.5` | 1.5, 0.5, 0.5 |
| Fraction | `1/2`, `3/4` | 0.5, 0.75 (a zero denominator makes the token a plain word) |
| Mixed number | `1 1/2`, `1-1/2`, `1½` | 1.5 |
| Unicode fraction | `½`, `¾` | 0.5, 0.75 |
| Number words | `one` to `nineteen`, `twenty` to `ninety`, and pairs such as `twenty five` or `twenty-five` | 1 to 99 |
| `a`, `an` (see 2.6 rule 5) | `an apple`, `a cup of milk`, `I had a banana` | 1 |
| Dozen | `dozen`, `a dozen`, `2 dozen`, `half a dozen` (optionally followed by `of`) | 12 times the quantity before it, or 12 if none: 12, 12, 24, 6 |
| Half | `half`, `a half`, `one half`, `half a`, `half an`, `half of a` | 0.5 |
| Quarter, third | `a quarter`, `quarter of a`, `a third`, `one third` | 0.25, 1/3 |
| Counted fractions | `three quarters`, `two thirds` (optionally followed by `of a`) | 0.75, 2/3 |
| Number phrases with "and" | `one and a half`, `1 and 1/2`, `a cup and a half` | see [2.4](#24-number-phrases-that-contain-and) |
| Couple | `a couple`, `a couple of`, `couple of` | 2 |

### 3.2 Multipliers

`2x`, `2 x`, `x2`, `x 2`, `2×`, `×2` (either case of x). A multiplier multiplies the item's quantity:

- `eggs x3` = 3 eggs; `2x eggs` = 2 eggs;
- `eggs 2x` = 2 eggs, the same as `eggs x2`: a number directly followed by `x` at the end of an item, after food words, is a trailing multiplier;
- `2x 100g chicken breast` = 200 g;
- `half usual breakfast x2` = 1 times the saved meal.

A multiplier with no other quantity is the quantity.

A multiplier may be written `2x` or `x2` at the start of an item, and `x2` or `2x` at its end: `x2 eggs` is 2 eggs, and `x2 usual breakfast` is the saved meal times 2.

### 3.3 Ranges

`2-3`, `2 to 3`, `2 or 3`, `1/2-1`: the quantity is the **midpoint** (2.5), and the line gets the "Assumed" marker so the user sees that a value was picked. See [open question 2](#142-open-questions).

A hyphen between a whole number and a fraction is a mixed number, not a range: `1-1/2` is 1.5. A hyphen between two fractions is a range: `1/2-3/4` is 0.625.

### 3.4 No quantity, vague words, approximations

- **No quantity at all**: the item gets the default amount ([4.6](#46-default-amount)) and the "Assumed" marker. Exception: a size word or a unit followed by `of` with no number means 1 (`large coffee`, `cup of coffee`, `slice of pizza`).
- **Vague words** `some`, `a few`, `few`, `a little`, `a bit`, `a bit of` count as no quantity.
- **Approximation words** `about`, `around`, `approximately`, `roughly`, `~` are ignored: `about 2 cups` is 2 cups.
- `0` is a valid quantity and gives 0 g.
- A number followed by `%` is part of the food name, never a quantity: `2% milk`, `100% orange juice`.

### 3.5 Not supported

One line each:

- Number words above ninety-nine ("two hundred"). Dictation on both platforms writes these as digits.
- Ordinals ("second helping").
- A comma as decimal point (`1,5`).
- Quantities written after units, such as `cups 2`.
- Numbers too large to read as a finite value. Such a number is not a quantity; the parser never produces an infinite or not-a-number amount.

## 4. Units, sizes and grams

### 4.1 Unit tokens

A word is read as a unit only **directly after a quantity** (or after a quantity and a size word), or when it is **followed by `of`** (`cup of coffee`). Everywhere else it is an ordinary word.

**Mass**: converted directly.

| Unit | Accepted spellings | Grams |
|---|---|---|
| g | `g`, `G`, `gr`, `gm`, `gms`, `gram`, `grams`, `gramme`, `grammes` | 1 |
| kg | `kg`, `kgs`, `kilo`, `kilos`, `kilogram`, `kilograms` | 1000 |
| mg | `mg`, `milligram`, `milligrams` | 0.001 |
| oz | `oz`, `ozs`, `ounce`, `ounces` | 28.349523125 (but see 4.2) |
| lb | `lb`, `lbs`, `pound`, `pounds` | 453.59237 |

**Volume**: converted through the food's portions (4.5). US customary measures.

| Unit | Accepted spellings | Milliliters |
|---|---|---|
| tsp | `t` (lower case only), `tsp`, `tsps`, `tspn`, `teaspoon`, `teaspoons`, `teaspoonful`, `teaspoonfuls` | 4.92892159375 |
| tbsp | `T` (upper case only), `tbsp`, `tbsps`, `tbs`, `tbl`, `tbls`, `tblsp`, `tablespoon`, `tablespoons`, `tablespoonful`, `tablespoonfuls` | 14.78676478125 |
| cup | `c`, `C`, `cup`, `cups`, `cupful`, `cupfuls` | 236.5882365 |
| fl oz | `fl oz`, `fl. oz.`, `fl.oz`, `floz`, `fl ounce`, `fl ounces`, `fluid ounce`, `fluid ounces` | 29.5735295625 |
| pint | `pint`, `pints`, `pt`, `pts` | 473.176473 |
| quart | `quart`, `quarts`, `qt`, `qts` | 946.352946 |
| gallon | `gallon`, `gallons`, `gal`, `gals` | 3785.411784 |
| ml | `ml`, `mls`, `milliliter`, `milliliters`, `millilitre`, `millilitres` | 1 |
| l | `l`, `L`, `liter`, `liters`, `litre`, `litres`, `ltr` | 1000 |

**Household and count units**: converted only through a portion of the food that names them (4.5). Each is accepted in the singular, with `s`, and with `es`. The `es` plural applies to whole words only; the abbreviations (`pc`, `svg`, `pkt`, `pkg`) take only `s`:

`slice`, `piece` (also `pc`, `pcs`), `serving` (also `svg`), `portion`, `can`, `bottle`, `glass`, `mug`, `bowl`, `scoop`, `clove`, `container`, `packet` (also `pkt`), `package` (also `pkg`), `bag`, `box`, `carton`, `jar`, `pouch`, `tub`, `bar`, `stick`, `pat`, `strip`, `link`, `patty` (plural `patties`), `fillet` (also `filet`), `wedge`, `leaf` (plural `leaves`), `stalk`, `spear`, `sprig`, `head`, `ear`, `handful`, `square`, `cube`, `sheet`, `shot`, `jigger`

Upper and lower case are the same for every unit spelling longer than one letter. A period right after a unit spelling is part of it (`tbsp.`) when the word is read as a unit there; see 2.2.

### 4.2 How ambiguous abbreviations are read

| Typed | Read as | Rule |
|---|---|---|
| `T` | tablespoon | upper case single letter |
| `t` | teaspoon | lower case single letter |
| `c`, `C` | cup | only directly after a number, so "vitamin c" is not affected |
| `g`, `G`, `l`, `L` | gram, liter | only directly after a number |
| `100g`, `2c`, `1T`, `1/2c`, `500ml` | number and unit | a number touching letters is split into number and word (2.1), so `100g` is `100 g`; `V8` (letters first) and `7up` (a synonym entry) stay words |
| `lb`, `lbs` | pound | the same unit |
| `oz` | **fluid ounce if the food has a "fl oz" portion, otherwise weight ounce** | 1,111 foods have a "fl oz" portion and they are almost all drinks, milks, juices, soups and liquid creams. Only one food has both a "fl oz" portion and a weight "oz" portion. So `8 oz milk` is 8 fl oz (244 g) and `3 oz salmon` is 85 g. See [open question 3](#142-open-questions). |
| `fl oz` | fluid ounce | always |

Local foods follow the same `oz` rule: a fluid ounce when the food has a "fl oz" portion, otherwise a weight ounce. On a local food measured in ml (base unit `ml`), a weight ounce cannot be converted (4.5), so the line gets the default amount (4.6).

### 4.3 Size words and "of"

**Size words**: `small`, `medium`, `large`, `big` (read as large), `extra large`, `extra-large`, `xl` (read as "extra large", the wording portion labels use), `jumbo`, `mini`, `miniature`, `regular`, `thin`, `thick`.

A size word is read as a size right after a quantity (`2 large eggs`), between a quantity and a unit (`3 thick slices toast`), or at the start of an item (`large coffee`, which means 1 large). It picks a portion (4.5). If the food has no portion with that size word, the size is ignored and the line keeps its state. FNDDS gives eggs one portion, "1 egg" = 50 g, which is a large egg, so `2 large eggs` is 100 g.

**"of"** after a quantity, size or unit is filler: `2 slices of toast`, `half of a bagel`, `a couple of eggs`.

### 4.4 Reading a food's portions

Each portion row has a label and a gram weight (`food_portion` for USDA foods, `food_portions` for local foods). A label is read as:

```
<amount> <unit phrase>[, <modifier> | (<note>)]
```

- **amount**: the leading number, such as `1`, `0.5`, `1 1/2`. Labels that do not start with a number ("Skin from 1 medium", 28 rows) are skipped. So are the 20 labels that start with a number range such as "1-3 ring", because their amount is unclear. So is a label whose number touches a symbol (such as `1" wedge`), whose amount is zero or has a zero denominator, or whose gram weight is zero or less.
- **unit phrase**: the words after the amount up to the first comma or opening bracket. In `1 cup, chopped` it is "cup"; in `1 medium or regular slice` it is "medium or regular slice"; in `1 cup (8 fl oz)` it is "cup".
- **unit**: `fl oz` if the unit phrase starts with it; otherwise the first word of the unit phrase if it is in the unit tables in 4.1. A one-letter word in a label is never a unit.
- **plain**: a label with nothing after the unit phrase.
- **grams per unit** = gram weight divided by amount.
- **label shown**: when a default (4.6) or a portion is shown as a line's unit, the unit label is the portion's label after its leading amount, with a leading unit word written in its canonical form from 4.1. "1 tablespoon" gives "tbsp"; "1 cup, cooked" gives "cup, cooked"; "1 drink (12 fl oz)" gives "drink (12 fl oz)". Examples 14, 40, 41 and 73 print it this way.

Portions are always taken in the stored order (`seq`), which is USDA's own order.

The FNDDS row labeled exactly `Quantity not specified` is the food's **default portion** (see 4.6 and [section 13](#13-changes-needed-outside-this-document)). It is never offered as a unit in the correction sheet: the portion pickers hide every label that starts with "Quantity not specified". Only the exact label counts as the default portion. One food, the antipasto usda:2706874, has the labels "Quantity not specified, if appetizer" and "Quantity not specified, if main course in meal" instead; neither is the default portion, so its default comes from 4.6 rule 5 (1 cup, 115 g).

### 4.5 Typed unit to grams

For a food F and an item with quantity q:

**Mass unit**: grams = q × the factor in 4.1.

**Volume unit U**:
1. If F has portions with unit U, take the first plain one, or else the first one. Grams = q × its grams per unit.
2. Otherwise, if F has any volume portion, take the first plain volume portion, or else the first volume portion, and scale by the milliliter ratio. Grams = q × (grams per unit of that portion) × ml(U) ÷ ml(its unit). This is how a food with only a cup portion gives tablespoons: FNDDS "Cream, half and half" has "1 cup" = 240 g and no tablespoon, so 1 tbsp = 240 × 14.787 ÷ 236.588 = 15 g.
3. Otherwise the unit cannot be converted for this food.

**`serving` or `portion`**: the first portion whose unit phrase contains "serving" (size word, then medium or regular, then first, as below). If there is none, one default portion (4.6). So "serving" always converts. In that case the unit label stays as typed (`serving` or `portion`), the amount is not assumed, and each serving weighs what the 4.6 default weighs: without the recipe in example 74, `2 servings chili` is matched as 2 × 255 g (default) of "Chili, NFS".

**Other household unit U**: the portions whose unit phrase contains U. Choose, in order: the first containing the typed size word; the first containing "medium" or "regular"; the first. Grams = q × its grams per unit. If there is no such portion, the unit cannot be converted. FNDDS "Bread, sour dough, toasted" has five slice portions; `2 slices` takes "1 medium or regular slice" (28 g), so 56 g.

**No unit (a bare count, such as `2 eggs`)**: the first rule that finds a portion wins:
1. a size word was typed: the first portion whose unit phrase contains it;
2. a portion whose unit phrase is exactly one word, and that word is one of the item's query words (its food words normalized as in 5.2, after typo correction), compared using the same plural rule (5.2 step 6): "1 egg", "1 banana", "1 sandwich", "1 breast". So `2 cookies` meets a "1 cookie" portion, and `2 bananna` uses "1 banana". "1 Bagel Thin" does not count for "bagel" because its unit phrase has two words;
3. the default portion from FNDDS (only the exact label "Quantity not specified", so a local food goes on to rules 4 and 5);
4. the first portion whose unit phrase contains "medium" or "regular";
5. the first portion whose unit is neither mass nor volume ("1 large", "1 pat");
6. otherwise the count cannot be converted.

Grams = q × the grams per unit of that portion. A bare count that found its portion by rule 1 has the size word as its unit label (`1 large`); one that found it by rules 2 to 5 has an empty unit label.

**Local foods** (user foods, recipes, cached Open Food Facts products) use the same rules with their `food_portions` rows. A local food's base amount must be above zero; a food that breaks this is left out of matching and can never be a line's food. Their base unit adds one rule: when it is `ml`, volume units convert directly and mass units do not; when it is `serving`, `serving` and bare counts convert directly and mass and volume units do not.

**When the unit cannot be converted**, the line gets the default amount (4.6) and the "Assumed" marker. The typed amount stays visible in the text. This is common in the data:
- 578 foods have no usable portion at all;
- 6,091 foods (45%) have no volume portion, mostly SR Legacy meats and Foundation foods;
- 926 have only mass portions ("3 oz", "1 lb").

### 4.6 Default amount

Used when no amount was typed, or the typed unit cannot be converted. The first rule that applies wins:

1. **Learned amount**: the learned match for this item's key has a quantity, and its unit converts for the food ([section 7](#7-learning-from-corrections)).
2. **FNDDS default portion**: the food's "Quantity not specified" gram weight. 5,362 of the 5,431 FNDDS foods have one. This is the amount USDA's own survey uses when a person does not say how much, so it is a sensible default. Examples from the data: egg 50 g, butter 14 g, half and half 20 g, sourdough toast 28 g (one medium slice), milk 244 g (1 cup), coffee 360 g, apple 200 g, rice 118 g.
3. The first portion whose unit phrase contains "medium" or "regular".
4. The first portion whose unit is neither mass nor volume.
5. The first portion.
6. 100 g.

For a local food: learned amount, then 1 serving if the base unit is `serving`, then its first portion, then its base amount and unit. The base amount is always above zero (4.5).

**How a default is stored and shown**, using the portion's label as shown in 4.4. The first of these that applies wins:
1. The default rule picked a portion whose amount is 1: the line shows and stores quantity 1 of that portion ("1 drink (12 fl oz)" in example 73). For a food whose rule picks "1 leek", it shows "1 leek", not another portion of the same weight.
2. Some portion with an amount of 1 has exactly the default's gram weight: the line shows and stores quantity 1 of the first such portion in USDA order. This is how the "Quantity not specified" default shows as "1 small" (360 g) for coffee.
3. Otherwise it shows and stores the amount in the food's base unit: grams ("20 g" for half and half), or `ml` for a local food measured by volume.

A learned amount (default rule 1) is not covered by these three: it is shown with the quantity and unit label that were learned, as example 52 prints it ("2 slice (learned)").

For typed items, amounts are not copied from past logs. Only an explicit amount correction is remembered (section 7). Added lines are different: a recent or frequent chip uses the amount last logged for that food, because the user picked that food on purpose ([9.3](#93-added-lines)).

### 4.7 What is stored for a line

When the meal is saved, each line (typed or added) becomes one `meal_entries` row:

| Column | Value |
|---|---|
| `food_ref`, `food_name` | the matched food and its name at the time |
| `position` | the line's order on screen: added lines first, in the order added, then typed lines in text order (9.3) |
| `quantity` | the typed quantity, after multipliers (or the default's quantity) |
| `unit_label` | the canonical unit (`g`, `oz`, `fl oz`, `tbsp`, `cup`, `slice`, ...), or the size word used as a unit (`large`), or the default portion's label as shown in 4.4 (`small`, `cup, cooked`), or an empty string for a bare count (4.5) |
| `base_quantity`, `base_unit` | grams and `g`; for a local food with base unit `ml` or `serving`, that amount and unit |

`meal_entry_nutrients` gets every nutrient the food has, scaled to the amount: USDA values are per 100 g, so amount = value × grams ÷ 100. `meals.source_text` keeps the whole typed text.

## 5. Matching an item to a food

### 5.1 Source order

For each item, after its amount is read, the remaining food text is looked up in this order. The first source that answers wins.

1. **Alias or saved meal**: exact phrase match ([section 6](#6-aliases-and-saved-meals)).
2. **Learned match**: exact key match ([section 7](#7-learning-from-corrections)). The line is matched.
3. **Ranked search** over one pool of candidates: the user's local foods (custom foods, recipes, cached Open Food Facts products, not archived, with a base amount above zero as 4.5 requires) and all USDA foods. The user's own foods come first whenever they fit the typed words (5.4 key 2). The user's history is part of the ranking (5.4 key 4), not a separate source, so a weak history match never beats a strong USDA match.

### 5.2 Normalizing text

The same steps are applied to typed food words and to food descriptions:

1. Lower case. Accents removed (é becomes e). Apostrophes removed.
2. Split into words made of letters, digits and `%`. Descriptions are also split into **segments** at commas and opening brackets.
3. **Negation**: `without`, `w/o` and `no` and every word after them in the same item are left out of matching. `coffee without sugar` matches "coffee". The words stay in the text box. The cut does not apply inside a protected user name (2.3): with a custom food named "No sugar cola", `no sugar cola` and `2 cans no sugar cola` find that food. An item with no amount whose words are all removed by this cut gives no line at all (8.1): `coffee with no sugar` splits at "with", and the second item, "no sugar", gives no line, so it cannot block Save. With a typed amount, such an item is not found: `2 no sugar` gives a not found line.
4. **Synonyms** (5.3) are applied to typed text. This comes before filler words are removed, because "pb and j" needs its "and".
5. **Filler words** are dropped from typed text: `a an the of and or with in on for to my i im had have ate eaten drank then also just made prepared topped plus about around approximately roughly`.
6. **Plurals**: words of 4 letters or more lose a plural ending, in this order:
   - `sses` becomes `ss`
   - `ies` becomes `y` in a word of 5 letters or more (berries, berry); a word of exactly 4 letters only drops the `s` (pies, pie)
   - `oes` becomes `o` (potatoes, potato)
   - `ches`, `shes`, `xes`, `zes` lose `es` (sandwiches)
   - otherwise a final `s` is dropped, except after `ss`, `us` or `is` (hummus, asparagus and couscous stay whole)

   A word of 5 letters or more that ends in `ie` also becomes the stem ending in `y`, so cookie and cookies meet at "cooky". Words of 4 letters or fewer that end in `ie` are unchanged (pie, brie). The stem is a matching key only and is never shown.

**Word order does not matter.** Matching compares sets of words, so `rice and beans` finds "Beans and white rice", and `greek yogurt` finds "Yogurt, Greek, ...".

**Joined words.** Each pair of neighboring words in one description segment is also indexed written together, except inside a segment that starts with "NS as to" (5.4). FNDDS spells it "Bread, sour dough", so `sourdough` matches "sour" plus "dough".

**Typos.** A typed word of 4 letters or more that is not in the index, and is not the start of any indexed word (so half-typed words are left alone), is replaced by the closest indexed word. The joined word pairs are part of the index here, so a half-typed `sourdoug` is left alone as the start of "sourdough" and is not corrected to another word. The distance is Damerau-Levenshtein, where swapping two neighboring letters counts as 1. The limit is 1 for words of 4 to 7 letters and 2 for 8 letters or more. Ties go to the word used by more foods, then to alphabetical order. **A line where any word was corrected this way is always a guess.** Examples from the data: `bananna` becomes banana, `chiken` becomes chicken, `brocoli` becomes broccoli, `oatmeel` becomes oatmeal.

There is no partial-word (prefix) matching. A half-typed word such as `sourd` matches nothing until it is finished, so lines do not flash odd foods while the user types. In the prototype, prefix matching turned `2 slices sourd` into "Sourdock, young leaves (Alaska Native)".

### 5.3 Synonyms

A short list kept in code, applied to typed text before matching, longest phrase first. Synonyms are applied after negation and before filler words and plurals are removed (5.2). Because they come before plurals are removed, each listed singular also matches its plural: `donuts`, `burgers`. A row that maps a phrase to itself protects that phrase from the shorter rows (so "french toast" is not turned into "french bread toasted").

| Typed | Matched as |
|---|---|
| french toast, melba toast | unchanged |
| toast | bread toasted |
| black coffee | coffee |
| dr pepper | soft drink pepper type |
| 7 up, 7up | lemon lime soda |
| v8 | tomato vegetable juice |
| fries | french fries |
| pb and j, pbj | peanut butter jelly |
| pb | peanut butter |
| oj | orange juice |
| evoo | olive oil |
| mac | macaroni |
| mayo | mayonnaise |
| coke | cola soft drink |
| soda | soft drink |
| burger | hamburger |
| yoghurt | yogurt |
| donut | doughnut |
| skim milk, nonfat milk | milk fat free skim |
| bbq | barbecue |
| cooked cereal, cereal bar | unchanged |
| cereal | cereal ready to eat |

Synonyms are applied once, in a single pass. Their output is never scanned again, so "7up" becomes "lemon lime soda" and that "soda" is not turned into "soft drink" (example 73 depends on this).

Each entry was checked against the data. "v8" gives the plain "Tomato and vegetable juice, 100%"; without it, `V8` matches "Beverages, V8 V-FUSION Juices, Tropical", a fruit and vegetable blend with more than twice the calories. Without "toast", the word only matches "French toast", "Melba toast" and the like, because USDA writes "Bread, white, toasted". Without "coke", the typo rule turns it into "cake". "skim milk" and "nonfat milk" find "Milk, fat free (skim)", and "cereal" finds "Cereal, ready-to-eat, NFS"; the identity rows "cooked cereal" and "cereal bar" stop the cereal row applying inside those phrases.

### 5.4 Candidates and ranking

The **query** is the item's food words after normalizing. Let n be the number of query words.

A food is a **candidate** if at least half of the query words, rounded up and at least 1, appear among its words (or its joined pairs). So a typed word found nowhere does not, on its own, make the item not found. `zorbo bar` (an unknown brand) matches "bar" only, half of its two words, and becomes a **guess** of "Breakfast bar, NFS" (1 bar by default, 43 g, 162 kcal). Whether such an item should be not found instead is [open question 11](#142-open-questions).

For each candidate, count its **extra words**: description words that are not query words and are not covered by a joined pair. Extra words are counted as distinct words, so a word that appears twice in a description counts once. These do not count as extra:
- the neutral words `nfs ns as to or and with of in whole plain regular raw fresh brewed cooked include` (compared after plural removal, so "Includes" in a description is "include");
- every word of a segment that starts with "NS as to" ("Coffee, NS as to type").

These words stay in the index, so a query can still match them; they just never count as extra words. Joined pairs are not built inside a segment that starts with "NS as to".

A food is **generic** if its description contains "NFS" or a segment starting with "NS as to". There are 509 such foods. They are USDA's own entries for "the person did not say which kind".

Candidates are sorted by these keys, in order:

1. More query words matched.
2. **The user's own food that fits** first. A food fits when every query word is in its name and the last word of its name (singular) is one of the query words. Trailing words of the name that contain a digit are skipped when finding that last word, because product names often end in a size or a percentage: a scanned "Fage Greek yogurt 0%" fits for `greek yogurt` once it has been logged. This applies to custom foods and recipes too. Only these local foods can fit: custom foods and recipes, and cached Open Food Facts products that the user has logged at least once. A product that was only scanned and never logged does not fit, so one scanned yogurt does not take over every later "yogurt". It is still a candidate, ranked by the other keys.
3. Fewer extra words.
4. More times logged by this user (count of `meal_entries` rows with this food ref). The count is kept per food ref, for USDA and local foods alike.
5. Generic before not generic.
6. Source: local foods, then FNDDS, then SR Legacy, then Foundation.
7. Shorter description.
8. Food reference text, alphabetical.

**The user's own foods against USDA (key 2).** The last word of a name is almost always the kind of food ("Turkey chili" is a chili; "Peanut butter cookies" are cookies). So:
- with a recipe named "Turkey chili", `2 servings chili` gives the recipe (2 servings), ahead of "Chili, NFS", even though "turkey" is an extra word;
- with a custom food named "Peanut butter cookies", `butter` still gives "Butter, NFS", because the food's last word is "cookies".

A user food that matches but does not fit (the cookies for `butter`) is ranked by the other keys like any food. The simpler rule, "the user's own foods always come first when they contain every typed word", was rejected because it gives the cookies for `butter`. See [open question 12](#142-open-questions).

**Why FNDDS, then SR Legacy, then Foundation.** FNDDS describes foods as eaten, has the generic entries and has the default portions. SR Legacy has more raw ingredients and many restaurant and brand entries ("McDONALD'S, Hamburger"). Foundation has only 374 foods, mostly raw ingredients, and 296 of them have no portions at all. The dataset is only the sixth key, so a better word match from any dataset still wins.

**How "egg" gets an egg.** For `egg` or `eggs`, the top candidate is "Egg, whole, cooked, NS as to cooking method" (usda:2707153): one word matched, no extra words ("whole" and "cooked" are neutral and "NS as to cooking method" is ignored), and generic. "Noodles, egg, ..." has the extra word "noodles", and "Egg substitute, ..." has "substitute", so both rank lower. "Egg, whole, raw" also has no extra words but is not generic, so it comes second.

### 5.5 Confident match or guess

The top candidate gives a **matched** line when all three are true:

1. Every query word was found in the food's words or joined pairs, and no typo correction was used.
2. The food has **no extra words**, or the user has logged this food before, or it is the user's own food that fits (key 2).
3. Every candidate that ties with it on sort keys 1 to 5 has energy within 10% (or 5 kcal, whichever is larger) per 100 g of the top candidate. In other words, if equally good matches differ in calories, the choice is shown as a guess. A food with no energy value counts as no evidence of a difference.

Otherwise the line is a **guess**. A guess still counts toward meal totals.

If there is no candidate, or the item has no food words, the line is **not found**.

**What this gives on real data.** On 141 common one- and two-word foods, 92 are matched and 49 are guesses. For example:
- matched: eggs, butter, toast, coffee, milk, banana, oatmeal, rice, bread, cheese, peanut butter, olive oil, honey;
- guess: yogurt (several equally generic yogurts), chicken breast (skin eaten or not), wine (red or white).

Allowing one extra word would make 120 of 141 matched, but it would also confidently pick "Vodka and lemonade" for `lemonade` and "Walnut oil" for `walnuts`. See [open question 5](#142-open-questions).

**History makes guesses confident.** Rule 2 lets a food the user has logged before match with extra words, and key 4 breaks ties in its favor. The first time, `2 tbsp half and half` is a guess, because "Cream, half and half" has the extra word "cream". Once the user has saved it once, the same text is matched.

### 5.6 Defaults from the real data

Top candidate for single words, with no user data:

| Typed | Top candidate | State |
|---|---|---|
| egg, eggs | Egg, whole, cooked, NS as to cooking method | matched |
| butter | Butter, NFS | matched |
| toast | Bread, NS as to major flour, toasted | matched |
| sourdough toast | Bread, sour dough, toasted | matched |
| coffee | Coffee, NS as to type | matched |
| milk | Milk, NFS | matched |
| half and half | Cream, half and half | guess (extra word "cream") |
| rice | Rice, cooked, NFS | matched |
| chicken | Chicken, NS as to part and cooking method, NS as to skin eaten | matched |
| salmon | Fish, salmon, NFS | guess (extra word "fish") |
| cream | Ice cream, NFS | guess |
| tea | Tea, ginger | guess |
| pizza | Pizza rolls | guess |
| walnuts | Walnut oil | guess |

The last four are poor defaults. The "Guess" marker flags each one, and one correction teaches the right food. Whether to add a hand-checked table of defaults for words like these is [open question 7](#142-open-questions).

### 5.7 The search box in the correction sheet

The search box uses the same normalizing and ranking on whatever the user types into it, including synonyms, typo correction and the user's own foods, exactly as matching does. There is one difference: a food is listed if it matches at least one word. It shows the top 20. (The plain LIKE search in `FoodReference.search` was removed with the temporary Data check screen in Phase 4.)

## 6. Aliases and saved meals

### 6.1 Recognizing a name

After an item's amount is read, its food words (with leading filler words dropped, 2.6 rule 1) are compared with:
1. every alias phrase (`aliases.phrase`);
2. every saved meal name (`saved_meals.name`).

Both sides go through the same key before they are compared: the clean-up in 2.1, then lower case, with accents and apostrophes dropped, any other punctuation turned into a space, and words separated by single spaces. So an alias saved as "pb&j" expands when `pb and j` is typed. There is no stemming and no other filler-word removal, and a word inside the user's own name is never filler (2.3), so "my" counts: `I had my oatmeal` matches an alias "my oatmeal", and `I had usual breakfast` matches "usual breakfast". The match must be exact. `usual breakfast` matches an alias "Usual breakfast"; `usual breakfasts` does not. Exact matching is what keeps expansions from happening by accident.

Names of two or more words are protected phrases (2.3), so they reach this step whole.

If two saved meals have the same normalized name, the newest (highest id) wins. An alias wins over a saved meal name. Two aliases with the same key cannot both be saved, so "pb&j" and "pb and j" cannot be saved as different aliases.

### 6.2 Quantity

- A plain quantity multiplies every item: `2 my oatmeal` is twice each item; `half usual breakfast` is half of each.
- A multiplier or range works the same way (a range also adds the "Assumed" marker to the header).
- `serving` or `portion` as the unit means the same as a plain quantity: `1 serving usual breakfast`.
- Any other unit means the text is not a saved meal. It is matched as food text instead.
- A size word before the name (`large usual breakfast`) also means the text is not a saved meal; it is read as ordinary food text.

### 6.3 Precedence

A saved meal or alias beats every food, including a learned match and an exact USDA name. A user who names a saved meal "oatmeal" gets the saved meal for `oatmeal`. To reach the USDA food, they rename the saved meal or alias, or pick a food in the correction sheet for that one line (6.4).

### 6.4 How the expansion is shown

- **Header line**, state **alias or saved meal**: the saved meal's name, the multiplier when it is not 1 (for example "× ½"), and the subtotal of kcal, protein, carbs and fat.
- **Item lines** below it, indented: each saved item with its amount times the multiplier, kcal and macros. They use the nutrient copy stored with the saved meal (`saved_meal_item_nutrients`), so they show as matched.
- Item lines count toward the meal total. The header does not add anything of its own.
- Tapping an item line opens the correction sheet for that item, for this meal only. It is not learned and does not change the saved meal.
- Tapping the header shows the multiplier, which can be edited (for a typed saved meal that rewrites the quantity in the text, as in 8.3), and "Use a food instead", which replaces the expansion with a normal search for this line only.
- Every change made from the header or an item line applies to this meal only. The saved meal itself is changed only in the saved meal editor.
- A saved meal chip tapped while the box has text adds the same header and item lines as an **added** saved meal (9.3), times 1. Its multiplier is edited on the line, since it has no text.
- On Save, each item becomes its own `meal_entries` row: quantity and `base_quantity` times the multiplier, nutrients times the multiplier.

## 7. Learning from corrections

### 7.1 The key

A learned match is stored under the item's **learned key**:
1. take the item's food words (size words already removed by the amount step), lower case them and split them into words, and remove filler words, as in 5.2 steps 1, 2 and 5. The negation cut (step 3) and the synonym table (step 4) are not applied to the key;
2. stem the words (5.2 step 6);
3. sort them alphabetically;
4. join with single spaces.

So:
- `toast` has the key "toast";
- `2 slices sourdough toast` has the key "sourdough toast";
- `toast, sourdough` would have the same key;
- `large coffee` has the key "coffee".

This is `learned_matches.phrase`. The table is used as it exists; no schema change is needed.

### 7.2 What is stored

Learning happens **when the meal is saved**, for each line the user corrected in the correction sheet and that is still in the text. A correction on a meal that is never saved teaches nothing.

| The user... | Then on Save |
|---|---|
| picked a food (including picking the guess itself, which confirms it) | Upsert the row for the key: `food_ref`, `food_name`, `updated_at_ms` = now. `times_used` is +1 if the row already pointed to this food, otherwise 1. If the food changed, `unit_label` and `quantity` are cleared, unless an amount was also set in this correction. |
| set an amount in the sheet on a line that was amount assumed, because no amount was typed or because the food could not convert the typed unit | Store `quantity` and `unit_label` on the row for the key, creating the row with the current food if there is none. This does not cover a typed range (`2-3 eggs`): a range is the user's own amount, and setting a number in the sheet for it teaches nothing. |
| set an amount on a line whose amount was typed | Nothing is learned. Typed amounts are not defaults. |
| saved a line that came from a learned row, unchanged | `times_used` +1 and `updated_at_ms` = now. |

Corrections made inside an expanded saved meal are never learned.

`quantity` null means no amount was learned. When `quantity` is set, `unit_label` holds the unit as in 4.7; an empty string means a bare count.

### 7.3 How it is applied

When an item's key equals a learned row's `phrase`, that food is the match and the line is **matched**. Ranking is skipped. The learned amount is used only when no amount was typed or the typed unit cannot be converted (4.6, rule 1).

A learned row only answers its exact key. Its other effect is indirect: once the meal is saved, the food has history, which helps it in ranking for other texts (5.4 key 4, 5.5 rule 2).

Added lines (9.3) have no typed text and therefore no key, so a food picked for an added line is never learned.

A learned row is ignored if its food no longer exists: a USDA id missing after a data update, or an archived local food. Ignored rows are left in place.

### 7.4 Undo and replace

- **Replace**: picking another food for the same key overwrites the row on Save.
- **Forget**: the correction sheet of a line matched by a learned row shows "Forget this match". It deletes the row at once, and the line re-parses with normal ranking. It acts immediately because it is an explicit command.
- A list of all learned matches in Settings is not part of this design.

## 8. Line states and the correction sheet

### 8.1 States

The state names are shared with the wireframes. The marker words are short so a line fits a 344 dp wide screen.

| State | When it applies | What the line shows | Counts toward totals |
|---|---|---|---|
| **matched** | A learned match; or the top candidate passes all three tests in 5.5; and the amount was typed and converted. Also every added line whose amount is known (9.3). | food name, amount (quantity, unit, grams), kcal, protein / carbs / fat | yes |
| **guess** | The top candidate fails a test in 5.5 (typo corrected, a query word not found, extra words on a food the user has never logged, or equally good candidates that differ in calories) | as matched, with the marker "Guess" | yes |
| **amount assumed** | The food is matched or guessed, and: no amount was typed; or the unit cannot be converted for this food; or a range was typed | as matched, with the default amount (4.6) and the marker "Assumed" | yes |
| **not found** | The item has food words but no candidate, or has an amount but no food words (`2 slices`, `200 g`) | the typed text, with the marker "Not found" | no |
| **alias or saved meal** | The item's text is an alias or saved meal name, or a saved meal was added from a chip | header and item lines (6.4) | the item lines do |

Two more markers describe where a food came from rather than a state:
- **"Your pick"**: the food was picked in the correction sheet during this session (a sticky correction, 9.1). It replaces "Guess" on that line.
- **"Scanned"**: an added line that came from a barcode scan (9.3).

A line can carry "Guess" and "Assumed" together, or "Your pick" and "Assumed". Precedence for the single state name used in prose and tests: not found, then alias or saved meal, then guess, then amount assumed, then matched.

An item made only of filler words ("I had") produces no line. Its text stays in the box and in `meals.source_text`. The same goes for any item with neither food words nor an amount: a vague word alone (`some`), or a lone `a` or `an`, which on its own is not an amount (2.6 rule 5). So `vitamin a` gives one line, for "vitamin". An item that has an amount but no food words is still not found, as in the table above and example 61. An item with no amount whose words are all removed by the negation cut (5.2 step 3) also gives no line: in `coffee with no sugar`, "no sugar" gives no line. With a typed amount, such an item has an amount but no food words, so it is not found: `2 no sugar` gives a not found line.

### 8.2 Not by color alone

Each marker is an icon **and** its word, and the same words are in the line's accessibility label:

| Marker | Word shown | When |
|---|---|---|
| guess | "Guess" | state guess |
| amount assumed | "Assumed" | state amount assumed, or a guess with an assumed amount |
| not found | "Not found" | state not found |
| your pick | "Your pick" | a food picked in the sheet this session |
| scanned | "Scanned" | an added line from a barcode |

A saved meal header has no marker word. It is recognized by its name, its multiplier and the indented item lines under it, and its spoken label starts with "Saved meal".

Example of a full spoken label: "Guess. Cream, half and half. 2 tablespoons, 30 grams. 39 calories. Double tap to change." Color may be added on top, never alone.

### 8.3 The correction sheet

Tapping any line opens it. Typed lines and added lines open the same sheet.

For a line that has a food:
- **Top**: the item's typed text (for an added line, the food name).
- **Candidates**: the current pick first, marked as chosen, then up to **7 others** in ranking order (5.4), skipping the current food. The list scrolls. Each row shows the food name, its dataset or "My food", and kcal for the line's amount. Added lines have no typed text to rank, so they show only the current food here.
- **A note under the list**: "Your pick is remembered when you save the meal." (For added lines and saved meal items, which are never learned, the note is left out.)
- **Search box**: below the list, as in 5.7.
- **Amount**: a quantity field and a unit picker. The picker offers only amounts that typed text can express for that food:
  - grams and ounces for any food measured in grams, which is every USDA food. A food of the user's that is measured in servings or milliliters with no weight does not offer them, because a weight cannot be converted for it (4.5). `oz` is not offered when, for that food, it would be read as a fluid ounce (4.2); `fl oz` is offered instead;
  - the volume units the food can convert (tsp, tbsp, cup, fl oz, ml) when it has any volume portion;
  - each of the food's own portions that can be typed, meaning that writing that unit into the item and re-parsing it gives the same food and that portion's grams;
  - a bare count and `serving`, whenever they re-parse to the same food, so a food of the user's with no portions can still have its amount changed. Each is listed only when no other listed choice has the same weight, so the same amount is not offered twice (coffee shows "small" once).

  A portion whose label cannot be typed back (for example "drink (12 fl oz)", or "medium or regular slice" when typing it would pick another portion or another food) is not offered, and neither is any portion whose label starts with "Quantity not specified".
- **Forget this match**: only when a learned match produced the line (7.4).
- **Remove from meal**: for a typed line, deletes the item's text from the box, checked by re-parsing: every other item must read exactly as before, otherwise nothing is removed. For an added line, it deletes the line.

For a **not found** line there are no candidate rows. The sheet has:
- the **search box**, filled in with the item's food words and with focus;
- **"Scan its barcode"**: the scanned product becomes this item's food, as a sticky correction marked "Scanned";
- **"Create a food"**: opens the custom food editor with the typed words as the name; when it is saved, the new food becomes this item's food, marked "Your pick";
- **"Remove from meal"**.

**Picking a food** on a typed line makes a sticky correction for that item (9.1), marked "Your pick". The text is not changed.

**Changing the amount** on a typed line rewrites only the item's amount in the text box: the old quantity and unit are replaced, or, if there was none, `<quantity> <unit> ` is put immediately before the item's first food word, after any leading filler (`I had toast` becomes `I had 2 slice toast`). When the new amount has no unit, an `of` left right after the old amount is removed (`2 slices of toast` set to 3 gives `3 toast`). Only numbers and units are ever written, never food names. The rewrite is checked by re-parsing: the new text must give the same amount. If the text cannot express the amount, the change is refused and nothing is rewritten. A typed saved meal header's multiplier (6.4) is changed the same way: the quantity in the text is rewritten and checked by re-parsing. See [open question 8](#142-open-questions). On an added line, the amount is changed on the line itself.

### 8.4 Save

The Save button changes its label instead of saving when a line is **not found**:

- With no not found line, it reads **"Save"** and saves the meal. Guesses and assumed amounts save as shown.
- With not found lines, it reads **"Fix 1 item"**, "Fix 2 items" and so on. Tapping it opens the correction sheet of the first not found line. Nothing is saved and nothing is dropped.
- A not found item that has the cursor in it is still being typed (9.2). It is drawn plain and not counted, so the button keeps reading "Save" and does not flicker while the user types. If Save is tapped then, that item is marked not found and its sheet opens. Nothing is saved.

## 9. Live re-parsing

The parser runs again on **every** change to the text, with no debounce. The speed targets in 12.3 make that safe.

### 9.1 Keeping a correction attached

Each typed line remembers the span of text it came from, and, when the user picked a food in the sheet, a **sticky correction** (a pick): the chosen food ref, the learned key (7.1) it was picked with, and its own item's span. A span is a pair of UTF-16 indexes into the text exactly as typed, before any clean-up (2.1). After every text change:

1. Find the changed region: the longest common start and the longest common end of the old and new text.
2. Carry each pick's span through the edit: text before the region keeps its positions, text after it shifts by the change in length, and a span that overlaps the region stretches or shrinks with it.
3. The pick's item is the new item that overlaps that span most. If that item's key equals the pick's key, the pick applies. Otherwise the pick is suspended, as described below.

So:
- typing `, 1 banana` at the end, one character at a time, keeps every correction above it;
- changing `2 slices toast` to `3 slices toast` keeps the chosen bread and recomputes the grams;
- changing it to `3 slices white toast` changes the key, so the pick is suspended and normal matching (learned row, then ranking) gives the line; it is dropped once the user moves on to another item (see below).

**A changed key suspends the pick; it does not drop it at once.** So changing an amount by backspacing does not lose a pick. While a pick is suspended, its line shows what a fresh parse shows, without "Your pick". An edit that changes that same item again, or that only adds or removes blanks next to it, keeps the pick suspended. When the item's key equals the pick's key again, the pick is restored. For example:
- `2 slices toast` with a picked bread: backspacing the 2 gives `slices toast`, whose key differs, so the pick is suspended; typing 3 gives `3 slices toast`, the key matches again, and the pick is back;
- `eggs` with a pick, then ` x3` typed after it: while the text reads `eggs x` the key differs, and `eggs x3` restores the pick;
- `2 slices toast` with the last word backspaced and typed again: the pick is suspended while the word is incomplete and back once `toast` is whole.

A suspended pick is dropped for good when:
- any edit leaves the pick's item as it was (the user has moved on), except an edit of blanks only with nothing but blanks between it and the item. So a comma typed right after the item, or text typed elsewhere, both count as moving on;
- its item disappears entirely, for example when it is backspaced to nothing. Typing the same words again later does not bring the pick back;
- a new pick is made on that item;
- the screen is closed.

A pick that applies is never dropped by typing elsewhere, never restored onto an item that an edit left unchanged, and never applied to two items. When two picks would claim the same item, the one whose span overlaps it most keeps it. A pick is never applied to a saved meal header.

Sticky corrections live in memory until Save. The phone's undo does not bring back a dropped correction. Added lines (9.3) are not tied to the text, so typing never changes them.

### 9.2 The half-typed last item

The parser has no special case for it. `2 sl` is not found, because "sl" is not a unit and matches no food.

The screen softens it. While the cursor is inside or at the end of a **not found** item, that line is drawn as plain typed text, with no marker, and it does not count toward the Save button's "Fix" label (8.4). It changes to the not found look when the cursor leaves the item, or when Save is tapped. While the cursor is at the end of the text and only spaces or tabs lie between the item's end and the cursor, the item still counts as under the cursor, so typing `2 ` does not show "Not found" for a moment. A new line or a comma ends the item as usual. A half-typed word never matches anything (5.2), so partial words do not flash odd foods.

### 9.3 Added lines

A food added without typing becomes an **added line**. It lives outside the text box and holds its food ref, quantity and unit directly. The parser never reads it and the app never writes food names into the text box.

Where added lines come from, and their amount:

| Source | Amount |
|---|---|
| Barcode scan | 1 serving of the product (its serving portion; if it has none, the default amount in 4.6, marked "Assumed"). Marked "Scanned". |
| A recent or frequent chip | The amount last logged for that food. The user picked this food on purpose, so its last amount is the best guess. 4.6 still holds for typed items. |
| A saved meal chip tapped while the box has text | The saved meal times 1, shown as a header with its item lines (6.4). (What the chip does with an empty box is part of the screen design, not the parser.) |
| Editing a logged meal | Its stored `meal_entries`, each with its stored amount and nutrient copy. The text box starts empty. Lines the user does not touch never change. |
| The saved meal and recipe editors | The existing items, each with its stored amount. |

Rules:
- **Order**: added lines are listed first, in the order they were added, then the typed lines in text order. Save writes `meal_entries.position` in that order.
- **Sheet**: added lines open the same correction sheet (8.3). A food picked there is not learned, because the line has no typed key (7.3).
- **Totals**: added lines count like matched lines.
- **`meals.source_text`** stores the typed text as it was when saved. It is a record only and is never re-parsed to rebuild a meal. When a logged meal is edited and more text is typed, the new text is added to the end of the stored `source_text` on a new line. A meal logged only from chips has a null `source_text`, which counts as empty. The record can mention lines that were later removed from the meal. No screen shows it as the meal's contents; the contents are always the `meal_entries` rows.

**Rejected alternative.** The first draft appended `, 1 serving <food name>` to the text for each added food, so the text box stayed the only source of truth. It was rejected because USDA names contain commas and "and" ("Bread, french or vienna, toasted (includes sourdough)", "Peanut butter and jelly sandwich, NFS"), so an inserted name re-parses as several items. Editing a logged meal the same way would also re-parse, and could change, lines the user never touched.

## 10. Grammar and token lists

### 10.1 Grammar

ISO 14977 style EBNF: `|` is a choice, `[ ]` optional, `{ }` zero or more, `(* *)` a comment. Words match without regard to case unless the token lists say otherwise. The grammar describes the text after the clean-up in 2.1, so `&`, `w/` and `w/o` never appear in it. A token with no letter or digit that no rule below uses is ignored (2.1). EBNF cannot express protected phrases (2.3) or where a quantity starts a new item (2.6); the rules in sections 2 to 4 decide those.

```ebnf
meal          = chunk , { hard_sep , chunk } ;
hard_sep      = NEWLINE | "," | ";" | "+" | "plus" | SENTENCE_END ;
chunk         = piece , { soft_sep , piece } ;
soft_sep      = "and" | "with" ;                  (* "&" and "w/" were replaced in 2.1 *)
piece         = item , { item } ;                 (* split by rule 2.6 *)

item          = { lead_filler } , [ amount ] , { lead_filler } , food , [ post_amount ] , [ negation ]
              | { lead_filler } , amount , [ negation ]
                                                  (* no food words: not found. A vague word or a
                                                     lone "a" alone is no amount and gives no line: 8.1 *)
              | { lead_filler } , negation ;      (* no amount, every word cut by negation: no line, 8.1 *)
lead_filler   = filler - ( "a" | "an" ) ;         (* "a" before any food word is the quantity 1 *)

amount        = lead_mult , [ measure ] , [ trail_mult ]
              | measure , [ trail_mult ] ;
measure       = quantity , [ size ] , [ unit , [ unit_half | unit_add , { unit_add } ] ] , [ "of" ]
              | size , [ unit ] , [ "of" ]          (* "large coffee" means 1 large *)
              | unit , "of"                       (* "cup of coffee" means 1 cup *)
              | vague , [ "of" ] ;                (* no quantity *)
unit_half     = "and" , ( "a" | "one" ) , "half" ;  (* "a cup and a half" *)
unit_add      = number , unit ;                   (* same kind as the first unit, never a household or
                                                     count unit: "1 lb 4 oz", "1 cup 2 tbsp 1 tsp", rule 2.6.3 *)
post_amount   = quantity , [ unit ] , [ trail_mult ] , { trail_word }
                                                  (* only where rule 2.6.2 allows *)
              | trail_mult
              | number , ( "x" | "×" ) ;          (* "eggs 2x": only at the end of the item, rule 3.2 *)
trail_word    = food_word | mid_filler ;          (* "chicken breast 6 oz grilled": rule 2.6.2 *)
lead_mult     = number , ( "x" | "×" ) | ( "x" | "×" ) , number ;
trail_mult    = ( "x" | "×" ) , number ;

quantity      = counted , [ range_tail ] ;
counted       = number_phrase , [ dozen ]
              | dozen ;                           (* "a dozen", "half a dozen", "dozen" *)
dozen         = ( "dozen" | "dozens" ) , [ "of" ] ;
range_tail    = ( "-" | "to" | "or" ) , number_phrase ;
number_phrase = whole , "and" , fraction_part     (* "1 and 1/2", "one and a half" *)
              | mixed
              | number
              | word_number
              | fraction_phrase
              | couple ;
mixed         = INTEGER , ( " " | "-" ) , FRACTION
              | INTEGER , VULGAR ;
number        = INTEGER | DECIMAL | FRACTION | VULGAR ;
whole         = INTEGER | word_number ;
fraction_part = FRACTION | VULGAR | fraction_phrase ;
fraction_phrase = [ "a" | "one" ] , ( "half" | "quarter" | "third" ) , [ "of" ] , [ "a" | "an" ]
              | whole , ( "quarters" | "thirds" ) , [ "of" ] , [ "a" | "an" ] ;
couple        = [ "a" ] , "couple" , [ "of" ] ;
(* Phrases starting with "a" ("a couple of", "a dozen", "a half", "a few",
   "a little", "a bit of", "a la") are matched first, longest first; only then
   is a lone "a" read as word_number. *)
word_number   = "a" | "an"                        (* where rule 2.6.5 reads them as 1 *)
              | ONES | TEENS | TENS , [ [ "-" ] , ONES ] ;

food          = [ name_number ] , food_word , { food_word | mid_filler } ;
name_number   = number , [ unit ] ;               (* only first, right after the amount: rule 2.6.3 *)
food_word     = WORD | PERCENT_WORD | protected_phrase ;
mid_filler    = filler - ( "a" | "an" ) ;         (* "a" after food words starts a new item *)
negation      = ( "without" | "no" ) , { any_token } ;
```

### 10.2 Token lists

| Token | Members |
|---|---|
| `INTEGER` | one or more digits |
| `DECIMAL` | digits, `.`, digits; or `.` then digits (`.5`) |
| `FRACTION` | digits `/` digits, the denominator not zero |
| `VULGAR` | ½ ⅓ ⅔ ¼ ¾ ⅕ ⅖ ⅗ ⅘ ⅙ ⅚ ⅐ ⅛ ⅜ ⅝ ⅞ ⅑ ⅒ |
| `WORD` | letters; letters followed by letters and digits (`V8`, `B12`), except `x` or `×` followed by digits, which is a multiplier; a number touching letters only when the whole word is a synonym entry, a built-in protected phrase or one of the user's names (`7up`) |
| `PERCENT_WORD` | a number directly followed by `%` (a food word) |
| `ONES` | one two three four five six seven eight nine |
| `TEENS` | ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen |
| `TENS` | twenty thirty forty fifty sixty seventy eighty ninety |
| `vague` | some, a few, few, a little, a bit, a bit of |
| approximation (ignored) | about, around, approximately, roughly, ~ |
| `size` | small, medium, large, big, extra large, extra-large, xl, jumbo, mini, miniature, regular, thin, thick |
| `unit` | the tables in 4.1 |
| `filler` | a an the of and or with in on for to my i im had have ate eaten drank then also just made prepared topped plus about around approximately roughly. "a" and "an" are filler only where rule 2.6.5 does not read them as 1. |
| neutral description words | nfs ns as to or and with of in whole plain regular raw fresh brewed cooked include (compared after plural removal) |
| protected phrases | the list in 2.3, plus the user's names |
| synonyms | the table in 5.3 |
| title abbreviations | dr mr mrs ms st jr sr vs |
| `SENTENCE_END` | a `.` followed by a space or the end of text, not right after a word read as a unit (2.2), `fl` or a title abbreviation, and not part of a number |
| symbol tokens (ignored) | a token with no letter or digit, such as `-`, `/`, `%` or `×` alone, that no quantity rule has used; never a food word (2.1) |

## 11. Worked examples

### 11.1 How to read and test these

- **Fixtures.** Unless a row says otherwise, the user has no history, no learned matches, no aliases and no saved meals.
- **Columns.** Each line shows the state, the food reference and name, the amount, the grams and the kcal.
- **Exactness.** A test passes when:
  - the number of lines is the same;
  - each line's state and food ref are the same. A saved meal header line has no food ref; it is compared by its state, name, multiplier and kcal subtotal. When an example lists no item lines under a header (example 50), only the header is compared (state, name, multiplier), and its items are not counted in the number of lines;
  - grams are within 0.05, where the example gives grams;
  - kcal is within 0.5, where the example gives kcal, computed as energy (1008) per 100 g × grams ÷ 100. A local food measured in servings has no grams, so its kcal is compared directly.
- **Reference data.** The examples assume the bundled data plus the FNDDS "Quantity not specified" portions, which the proposed build change in [section 13](#13-changes-needed-outside-this-document) keeps. Every amount that comes from that portion is marked "(default)". Amounts from the other default rules name the rule, for example "(default rule 4)".

Saved meal fixtures for examples 47 to 50:
- **"Usual breakfast"**, alias "usual breakfast":
  - 2 egg, usda:2707153, 100 g, 176 kcal;
  - 1 slice, usda:2707647, 28 g, 83.7 kcal.
- **"My oatmeal"**, alias "my oatmeal":
  - 1 cup, usda:2708380, 240 g, 182.4 kcal;
  - 1 tbsp, usda:2710281 (Honey), 20 g, 60.8 kcal.
- **"Eggs and toast"**, a saved meal name with no alias. Its items do not matter for the test.

User food fixtures for examples 74 and 75:
- **local:1 "Turkey chili"**, a recipe with base unit `serving`, 420 kcal per serving.
- **local:2 "Peanut butter cookies"**, a custom food with base unit `g`, one portion "1 cookie" = 20 g.

### 11.2 Examples

| # | Input | Expected lines | Why |
|---|---|---|---|
| 1 | `2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half` | 1. matched: usda:2707153 Egg, whole, cooked, NS as to cooking method; 2 (1 egg = 50 g); 100 g; 176 kcal; P 11.8, C 0.9, F 13.9<br>2. matched: usda:2707647 Bread, sour dough, toasted; 2 slice (medium or regular); 56 g; 167 kcal; P 6.6, C 31.9, F 1.5<br>3. matched: usda:2710154 Butter, NFS; 1 tbsp; 14 g; 104 kcal; P 0.1, C 0.0, F 11.5<br>4. amount assumed: usda:2710373 Coffee, NS as to type; 1 small (default); 360 g; 4 kcal; P 0.4, C 0.0, F 0.1<br>5. guess: usda:2705594 Cream, half and half; 2 tbsp; 30 g (from 1 cup = 240 g); 39 kcal; P 0.9, C 1.3, F 3.5<br>Meal total 490 kcal. | The brief's example. "with" splits, "half and half" is protected. Line 5 is a guess only because of the extra word "cream" (see 5.5). |
| 2 | `two eggs two slices of sourdough toast one tablespoon of butter and coffee with two tablespoons of half and half` | The same 5 lines as example 1. | Dictation. A quantity after food words starts a new item (2.6). |
| 3 | `2 tbsp half and half`, with history: usda:2705594 logged once | 1. matched: usda:2705594; 2 tbsp; 30 g; 39 kcal | History turns example 1's guess into a match. |
| 4 | `2 eggs and toast` | 1. matched: usda:2707153; 2; 100 g; 176 kcal<br>2. amount assumed: usda:2707592 Bread, NS as to major flour, toasted; 1 medium or regular slice (default); 25 g; 73 kcal | "and" splits. "toast" is a synonym for "bread toasted". |
| 5 | `half and half` | 1. guess, amount assumed: usda:2705594 Cream, half and half; 20 g (default); 26 kcal | "half" is not read as a quantity inside a protected phrase. |
| 6 | `mac and cheese` | 1. guess, amount assumed: usda:2708811 Macaroni or noodles with cheese; 1 cup (default); 230 g; 513 kcal | Protected. "mac" is a synonym. Extra word "noodles". |
| 7 | `peanut butter and jelly sandwich` | 1. amount assumed: usda:2707554 Peanut butter and jelly sandwich, NFS; 1 sandwich (default); 112 g; 404 kcal | Protected, generic, no extra words. |
| 8 | `rice and beans` | 1. guess, amount assumed: usda:2708990 Beans and white rice; 1 cup (default); 170 g; 279 kcal | Protected. Word order is ignored. |
| 9 | `chicken and rice` | 1. amount assumed: usda:2705929 Chicken, NS as to part and cooking method, NS as to skin eaten; 85 g (default); 139 kcal<br>2. amount assumed: usda:2708402 Rice, cooked, NFS; 118 g (default); 152 kcal | Not protected, so it splits ([open question 1](#142-open-questions)). |
| 10 | `chicken with broccoli` | 1. amount assumed: usda:2705929; 85 g (default); 139 kcal<br>2. amount assumed: usda:2709647 Broccoli, NS as to form, cooked; 80 g (default); 50 kcal | FNDDS has no chicken with broccoli dish. |
| 11 | `coffee with milk` | 1. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal<br>2. amount assumed: usda:2705384 Milk, NFS; 1 cup (default); 244 g; 127 kcal | |
| 12 | `coffee w/ cream & sugar` | 1. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal<br>2. guess, amount assumed: usda:2705629 Ice cream, NFS; 1 cup (default); 135 g; 298 kcal<br>3. amount assumed: usda:2710257 Sugar, NFS; 8 g (default); 32 kcal | `w/` and `&` split. "cream" is a known poor default ([open question 7](#142-open-questions)). |
| 13 | `gin and tonic` | 1. amount assumed: usda:2710633 Gin and tonic; 1 drink (default); 225 g; 189 kcal | Protected. |
| 14 | `oatmeal made with milk` | 1. amount assumed: usda:2708380 Oatmeal, NFS; 1 cup, cooked (default); 240 g; 182 kcal<br>2. amount assumed: usda:2705384; 1 cup (default); 244 g; 127 kcal | "with" splits. "made" is filler. |
| 15 | `burger and fries` | 1. amount assumed: usda:2706920 Hamburger, NFS; 1 hamburger (default); 145 g; 418 kcal<br>2. guess, amount assumed: usda:2709456 Potato, french fries, NFS; 110 g (default); 248 kcal | Synonyms "burger" and "fries". |
| 16 | `1 and 1/2 cups oatmeal` | 1. matched: usda:2708380; 1.5 cup ("1 cup, cooked" = 240 g); 360 g; 274 kcal | Number phrase with "and". |
| 17 | `one and a half cups of milk` | 1. matched: usda:2705384; 1.5 cup; 366 g; 190 kcal | |
| 18 | `a cup and a half of milk` | 1. matched: usda:2705384; 1.5 cup; 366 g; 190 kcal | Unit, then "and a half". |
| 19 | `1½ cups milk` | 1. matched: usda:2705384; 1.5 cup; 366 g; 190 kcal | Unicode fraction. |
| 20 | `1-1/2 cups milk` | 1. matched: usda:2705384; 1.5 cup; 366 g; 190 kcal | Mixed number with a hyphen. |
| 21 | `1 1/2 cups milk` | 1. matched: usda:2705384; 1.5 cup; 366 g; 190 kcal | |
| 22 | `three quarters of a cup of milk` | 1. matched: usda:2705384; 0.75 cup; 183 g; 95 kcal | |
| 23 | `.5 cup almonds` | 1. matched: usda:2707485 Almonds, NFS; 0.5 cup; 70.5 g; 422 kcal | Leading decimal point. |
| 24 | `half a bagel` | 1. matched: usda:2707684 Bagel; 0.5 × 105 g (default); 52.5 g; 139 kcal | Bare count uses the default portion (4.5 rule 3). "1 Bagel Thin" is not used. |
| 25 | `a couple of eggs` | 1. matched: usda:2707153; 2; 100 g; 176 kcal | |
| 26 | `an apple` | 1. matched: usda:2709215 Apple, raw; 1 × 200 g (default); 200 g; 122 kcal | |
| 27 | `eggs x3` | 1. matched: usda:2707153; 3; 150 g; 264 kcal | Trailing multiplier. |
| 28 | `2x 100g chicken breast` | 1. guess: usda:2705953 Chicken breast, NS as to cooking method, skin eaten; 200 g; 350 kcal | Leading multiplier. Guess: extra words "skin eaten". |
| 29 | `2-3 eggs` | 1. amount assumed: usda:2707153; 2.5; 125 g; 220 kcal | A range uses the midpoint and is marked. |
| 30 | `chicken breast 6 oz` | 1. guess: usda:2705953; 6 oz; 170.1 g; 298 kcal | Amount after the food. |
| 31 | `8 oz milk` | 1. matched: usda:2705384; 8 fl oz; 244 g; 127 kcal | Milk has a "1 fl oz" portion, so oz means fl oz. |
| 32 | `3 oz salmon` | 1. guess: usda:2706285 Fish, salmon, NFS; 3 oz; 85 g; 233 kcal | No fl oz portion, so oz is weight. |
| 33 | `1 T peanut butter, 1 t honey` | 1. matched: usda:2707537 Peanut butter; 1 tbsp; 16 g; 96 kcal<br>2. matched: usda:2710281 Honey; 1 tsp (from "1 tablespoon" = 20 g); 6.7 g; 20 kcal | Upper case T, lower case t. |
| 34 | `2c rice` | 1. matched: usda:2708402; 2 cup ("1 cup, cooked" = 158 g); 316 g; 408 kcal | Number touching a unit. |
| 35 | `500 ml milk` | 1. matched: usda:2705384; 500 ml (from 1 cup = 244 g); 515.7 g; 268 kcal | Milliliters from a cup portion. |
| 36 | `a large coffee` | 1. matched: usda:2710373; 1 large; 600 g; 6 kcal | Size word picks "1 large". |
| 37 | `large coffee` | 1. matched: usda:2710373; 1 large; 600 g; 6 kcal | A size word alone means 1. |
| 38 | `2 large eggs` | 1. matched: usda:2707153; 2 (1 egg); 100 g; 176 kcal | No "large" portion, so the size is ignored. |
| 39 | `3 thick slices toast` | 1. matched: usda:2707592; 3 slice ("1 large or thick slice" = 39 g); 117 g; 343 kcal | Size between number and unit. |
| 40 | `2 slices butter` | 1. amount assumed: usda:2710154; 1 tbsp (default 14 g); 14 g; 104 kcal | Butter has no slice portion, so the unit cannot be converted. |
| 41 | `1 bowl of oatmeal` | 1. amount assumed: usda:2708380; 1 cup, cooked (default); 240 g; 182 kcal | "bowl" is a unit, but this food has no bowl portion. |
| 42 | `2 bananna` | 1. guess: usda:2709224 Banana, raw; 2 ("1 banana" = 126 g); 252 g; 244 kcal | Typo corrected, so guess. The corrected word picks the "1 banana" portion (4.5 rule 2), as in example 43. |
| 43 | `I had two eggs and a banana` | 1. matched: usda:2707153; 2; 100 g; 176 kcal<br>2. matched: usda:2709224; 1 ("1 banana" = 126 g); 126 g; 122 kcal | Filler words ignored. "a" at the start of an item is 1. |
| 44 | `chicken 200g rice 1 cup` | 1. matched: usda:2705929; 200 g; 328 kcal<br>2. matched: usda:2708402; 1 cup; 158 g; 204 kcal | Amounts after foods, no commas. |
| 45 | `2 eggs. coffee` | 1. matched: usda:2707153; 100 g; 176 kcal<br>2. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal | End of sentence splits. |
| 46 | `2 eggs` new line `1 banana; black coffee` | 1. matched: usda:2707153; 100 g<br>2. matched: usda:2709224; 126 g<br>3. amount assumed: usda:2710373; 1 small (default); 360 g | New line and semicolon split. "black coffee" is a synonym for coffee. |
| 47 | `usual breakfast` | 1. alias or saved meal: "Usual breakfast" × 1; 260 kcal<br>1a. matched: usda:2707153; 2; 100 g; 176 kcal<br>1b. matched: usda:2707647; 1 slice; 28 g; 84 kcal | Fixture above. |
| 48 | `half usual breakfast, coffee` | 1. alias or saved meal: "Usual breakfast" × 0.5; 130 kcal<br>1a. matched: usda:2707153; 1; 50 g; 88 kcal<br>1b. matched: usda:2707647; 0.5 slice; 14 g; 42 kcal<br>2. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal | A quantity scales every item. |
| 49 | `2 my oatmeal` | 1. alias or saved meal: "My oatmeal" × 2; 486 kcal<br>1a. matched: usda:2708380; 2 cup; 480 g; 365 kcal<br>1b. matched: usda:2710281; 2 tbsp; 40 g; 122 kcal | "my" is kept for alias matching. |
| 50 | `eggs and toast, coffee` | 1. alias or saved meal: "Eggs and toast" × 1<br>2. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal | The saved meal name is protected, so "and" does not split it. |
| 51 | `2 slices toast`, with learned row "toast" for usda:2707756 and no amount | 1. matched: usda:2707756 Bread, rye, toasted; 2 slice (29 g each); 58 g; 165 kcal | A learned match beats ranking. |
| 52 | `toast`, with learned row "toast" for usda:2707756, quantity 2, unit "slice" | 1. amount assumed: usda:2707756; 2 slice (learned); 58 g; 165 kcal | A learned amount is the default. It is still marked, because nothing was typed. |
| 53 | `1 cup egg noodles` | 1. guess: usda:169732 Noodles, egg, enriched, cooked; 1 cup; 160 g; 221 kcal | "egg" does not take over a longer name. |
| 54 | `french toast` | 1. amount assumed: usda:2708331 French toast, NFS; 60 g (default); 164 kcal | The identity synonym blocks "toast". |
| 55 | `coffee without sugar` | 1. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal | Words after "without" are ignored. |
| 56 | `2% milk` | 1. guess, amount assumed: usda:2705386 Milk, reduced fat (2%); 1 cup (default); 244 g; 122 kcal | "2%" is a word, not a quantity. |
| 57 | `1 oz cheese, 2 tbsp. peanut butter` | 1. matched: usda:2705704 Cheese, NFS; 1 oz; 28.3 g; 108 kcal<br>2. matched: usda:2707537; 2 tbsp; 32 g; 191 kcal | Period after a unit is not a sentence end. |
| 58 | `2 eggs + 1 banana plus coffee` | 1. matched: usda:2707153; 100 g<br>2. matched: usda:2709224; 126 g<br>3. amount assumed: usda:2710373; 1 small (default); 360 g | `+` and "plus" split. |
| 59 | `asdfgh` | 1. not found: "asdfgh" | No candidate. |
| 60 | `purple monkey dishwasher` | 1. not found: "purple monkey dishwasher" | Fewer than half the words match any food. |
| 61 | `200 g` | 1. not found: "200 g" | Amount but no food. |
| 62 | `2 eggs, 2 sl` with the cursor at the end | 1. matched: usda:2707153; 100 g<br>2. not found: "2 sl", drawn as plain typing (9.2) | The half-typed last item. |
| 63 | `!!!` or `,,, and` | no lines | Nothing but separators. |
| 64 | `black coffee two eggs and toast` | 1. amount assumed: usda:2710373; 1 small (default); 360 g; 4 kcal<br>2. matched: usda:2707153; 2; 100 g; 176 kcal<br>3. amount assumed: usda:2707592; 1 medium or regular slice (default); 25 g; 73 kcal | "two" has no unit and is followed by "eggs", so it starts a new item (2.6 rule 2). |
| 65 | `two eggs a banana` | 1. matched: usda:2707153; 2; 100 g; 176 kcal<br>2. matched: usda:2709224; 1 ("1 banana"); 126 g; 122 kcal | "a" after food words starts a new item (2.6 rule 5). |
| 66 | `I had a banana` | 1. matched: usda:2709224; 1; 126 g; 122 kcal | With only filler before it, "a" is the quantity 1. |
| 67 | `a dozen eggs` | 1. matched: usda:2707153; 12; 600 g; 1056 kcal | |
| 68 | `half a dozen eggs` | 1. matched: usda:2707153; 6; 300 g; 528 kcal | |
| 69 | `2 eggs x3` | 1. matched: usda:2707153; 6; 300 g; 528 kcal | A multiplier after an amount multiplies it. |
| 70 | `1/2-3/4 cup milk` | 1. amount assumed: usda:2705384; 0.625 cup; 152.5 g; 79 kcal | A hyphen between two fractions is a range. |
| 71 | `1 can Dr. Pepper` | 1. matched: usda:2710545 Soft drink, pepper type; 1 can ("1 can (12 fl oz)" = 372 g); 372 g; 156 kcal | The period after "Dr" is not a sentence end. Synonym "dr pepper". |
| 72 | `1 can V8` | 1. guess, amount assumed: usda:2709731 Tomato and vegetable juice, 100%; 248 g (default); 55 kcal | "V8" stays one word, and the synonym gives the plain vegetable juice. Guess: extra word "100%". The food has no can portion, so the amount is the default. |
| 73 | `7up` | 1. guess, amount assumed: usda:173205 Beverages, carbonated, lemon-lime soda, no caffeine; "1 drink (12 fl oz)" (default rule 4); 368 g; 151 kcal | "7up" stays one word. Synonym "7up". |
| 74 | `2 servings chili`, with fixture local:1 | 1. matched: local:1 Turkey chili; 2 serving; 840 kcal | The user's own food fits (5.4 key 2). Without the recipe the line is matched: usda:2706373 Chili, NFS; 2 × 255 g (default); 510 g; 602 kcal. |
| 75 | `butter`, with fixture local:2 | 1. amount assumed: usda:2710154 Butter, NFS; 1 tbsp (default); 14 g; 104 kcal | The cookies do not fit: their last word, "cookies", was not typed. |
| 76 | `2 slices 12 grain bread` | 1. guess: usda:2707706 Bread, whole grain white; 2 slice (medium or regular); 72 g; 171 kcal | A second number before food words is part of the name (2.6 rule 3). No food has all three words "12", "grain" and "bread", so the best match is a guess. |
| 77 | `zorbo bar` | 1. guess, amount assumed: usda:2708114 Breakfast bar, NFS; 1 bar (default); 43 g; 162 kcal | Half the words matched is enough to be a candidate ([open question 11](#142-open-questions)). |
| 78 | `leftover pizza` | 1. guess, amount assumed: usda:2708686 Pizza rolls; 85 g (default); 293 kcal | Same rule. "leftover" is not in the data. |
| 79 | `chicken breast 6 oz grilled` | 1. guess: usda:2705969 Chicken breast, grilled with sauce, skin eaten; 6 oz; 170.1 g; 344 kcal | Words after an amount typed after the food stay with the item (2.6 rule 2). |
| 80 | `rice 1 cup cooked` | 1. matched: usda:2708402 Rice, cooked, NFS; 1 cup; 158 g; 204 kcal | One item, not two. |
| 81 | `chicken 200g rice 1 cup cooked` | 1. matched: usda:2705929; 200 g; 328 kcal<br>2. matched: usda:2708402; 1 cup; 158 g; 204 kcal | "rice" leaves with its own amount after the food; "cooked" stays with the rice. |
| 82 | `chicken 200g rice` | 1. guess: usda:2706438 Chicken curry with rice; 200 g; 232 kcal | The rice has no amount of its own, so it stays with the chicken. A stated cost of rule 2. |
| 83 | `1 lb 4 oz steak` | 1. matched: usda:2705823 Steak, NS as to type of meat, NS as to fat eaten; 1.25 lb; 567 g; 1304 kcal | Compound mass amount (2.6 rule 3). |
| 84 | `1 cup 2 tbsp milk` | 1. matched: usda:2705384; 1.125 cup; 274.5 g; 143 kcal | Compound volume amount. |
| 85 | `2eggs` | 1. matched: usda:2707153; 2; 100 g; 176 kcal | A number touching letters is split (2.1). |
| 86 | `1/2c milk` | 1. matched: usda:2705384; 0.5 cup; 122 g; 63 kcal | A fraction touching a unit. |
| 87 | `a half cup milk` | 1. matched: usda:2705384; 0.5 cup; 122 g; 63 kcal | "a half" is matched as a phrase before "a". |
| 88 | `a few almonds` | 1. amount assumed: usda:2707485 Almonds, NFS; 28 g (default); 167 kcal | "a few" is a vague phrase, so no quantity. |

## 12. Limits and speed

### 12.1 Out of scope

- **AI parsing** of any kind, on the device or in the cloud (the brief puts it out of scope). There is no language model and no network call.
- Typing calories directly ("200 kcal of chips").
- Cooking method inferred from context.
- Notes, times or places in the text ("at 7am", "at work").
- Abbreviations other than the synonym list ("choc chip").
- "Same as yesterday" typed as text. It is a button on the screen.
- Imperial (UK) pints and the 250 ml metric cup.
- Learning a gram weight for a household unit the food lacks ("my scoop is 31 g"). The workaround is to enter grams once, which teaches the amount for that item text.
- A lone describing word after a separator. `coffee, black` reads "black" as an item of its own, which may match a food as a guess. This is a known limit.

### 12.2 Locale

English words only. US customary volume units. A decimal point, never a decimal comma: a comma always separates items, so `1,5 kg` gives "1" and "5 kg", both not found. Number display may follow the phone's locale; parsing does not.

### 12.3 Speed

The text field must never wait for the parser. The parser runs on **every** text change, with **no debounce**.

| Target | Value |
|---|---|
| Where it runs | Parsing and matching run on a background isolate. The text field is never blocked. Results arrive in the order the parses were requested, and a result is discarded only if a result for newer text has already been shown. |
| Search index | Built once in the background at app start: all USDA descriptions, local foods and history counts. Ready within 1 second of launch on the test phones. |
| Re-parse after one keystroke | p95 of 16 ms or less on the Android test phone. Items whose text did not change reuse their cached result, keyed by item text and a version number that changes whenever user foods, learned matches, aliases or saved meals change. |
| Full parse of 10 new items | 50 ms or less on the Android test phone. |
| How it is checked | A Phase 4 benchmark test over the worked examples on the CI machine, plus a timing run on Bart's phone. |

The index is an in-memory map from word (and joined word pair) to food ids. Ranking only scores foods that share a word with the query, so it never scans all 13,598 foods.

## 13. Changes needed outside this document

Phase 3 changes no code. Everything below is for Phase 4.

**User database: no schema change.**
- `learned_matches` holds the key, food, and learned quantity and unit as specified in section 7.
- `meal_entries` and `meals.source_text` hold everything a line produces, typed or added.
- History counts are a query on `meal_entries`. No new index is needed at version 1 sizes; the counts are loaded with the search index.

**Proposed Phase 4 change to the reference database build, needing Bart's approval.** `tools/build_food_db.py` currently drops the FNDDS portion labeled "Quantity not specified". This design uses it as the default amount (4.6). The proposed change:
- keep that row in `food_portion` with its label unchanged;
- no table or column changes;
- the data version changes on its own because the file contents change;
- the portion pickers must hide that label (the temporary Data check screen, which also hid it, was removed in Phase 4). The pickers hide every portion label that starts with "Quantity not specified", which also covers the antipasto food's two longer labels (4.4).

Without it, defaults fall back to rules 3 to 6 of 4.6, which give worse amounts for drinks. For example, coffee would default to "1 medium" (480 g) instead of 360 g, and every example marked "(default)" in section 11 would change. This is [open question 4](#142-open-questions).

**Code that Phase 4 adds:**
- the search index and ranking (replacing `FoodReference.search` for parsing);
- the built-in protected phrase and synonym lists, each entry with a test;
- added lines (9.3) and the Save button's "Fix" label (8.4);
- the example table above as unit tests.

## 14. Decisions and open questions for Bart

### 14.1 Decided in review

These were settled during the Phase 3 review and are written into the sections above. They are listed here so Bart can see what was given up.

1. **Foods added without typing are added lines** (9.3).
   - **Chosen:** barcode scans, recent and frequent chips, saved meal chips tapped while the box has text, the stored entries of a meal being edited, and the items in the saved meal and recipe editors become added lines outside the text box. The app never writes food names into the text.
   - **Rejected:** appending `, 1 serving <food name>` to the text with the food pinned. USDA names contain commas and "and", so an inserted name re-parses as several items, and re-parsing an edited meal could change lines the user never touched.
2. **Save with a not found line** (8.4).
   - **Chosen:** the Save button reads "Fix 1 item" (with the count), and tapping it opens the first not found line's sheet. Nothing is saved. A not found item that still has the cursor is not counted, so the label does not flicker while typing.
   - **Rejected:**
     - Save scrolls to the line and shows a message (the first draft);
     - save the other lines and keep the not found text in the box;
     - save the not found text as an entry with no nutrients, which would need a new kind of food reference.

### 14.2 Open questions

Each has two or more reasonable readings. The recommendation is listed first.

1. **"and" or "with" with no quantity after it.**
   - **(a) Recommended:** always split, except for protected phrases (2.3). "chicken and rice" gives two lines. This is predictable, and the user sees exactly how the text was read.
   - (b) Keep the phrase whole when it matches a single food well, so "chicken and rice" becomes the FNDDS dish "Chicken or turkey and rice". Splitting would then depend on the data, which is harder to predict and test.

2. **Ranges ("2-3 eggs").**
   - **(a) Recommended:** midpoint, with the "Assumed" marker.
   - (b) The upper number (counts more calories).
   - (c) The lower number.

3. **"oz" for liquids.**
   - **(a) Recommended:** fluid ounce when the food has a "fl oz" portion, otherwise weight.
   - (b) Always weight. For milk, 8 oz is then 227 g instead of 244 g.

4. **Default amounts.**
   - **(a) Recommended:** approve the proposed build change in section 13 (keep FNDDS "Quantity not specified") and use it as the default.
   - (b) Do without it and use the portion rules alone.

5. **How strict "matched" is.**
   - **(a) Recommended:** a food with any extra word is a guess until the user has logged it once. This gave 92 of 141 common words as matched.
   - (b) Allow one extra word. This gave 120 of 141, but it confidently picks wrong foods, such as "Vodka and lemonade" for "lemonade" and "Walnut oil" for "walnuts".

6. **Hand-made lists in code** (protected phrases in 2.3, synonyms in 5.3).
   - **(a) Recommended:** ship these two short lists, each entry tested against the data.
   - (b) No lists. "toast" then matches "French toast" and "half and half" splits.

7. **Poor single-word defaults** (cream, tea, pizza, walnuts).
   - **(a) Recommended:** accept them for now. They show as guesses and one correction fixes them. Look again at the Phase 5 friction log.
   - (b) Add a hand-checked table mapping the most common single words to a food id.

8. **Changing the amount of a typed line in the correction sheet.**
   - **(a) Recommended:** rewrite the amount (numbers and unit only) in the text. The unit picker offers only amounts the text can express for that food, the rewrite is checked by re-parsing, and a change the text cannot express is refused (8.3).
   - (b) Keep a sticky amount override and leave the text alone. The text and the line would then disagree.

9. **When learning is written.**
   - **(a) Recommended:** on Save.
   - (b) The moment the user picks a food. Abandoned meals would then teach too.

10. **A saved guess counts as history.**
    - **(a) Recommended:** yes. Saving a guess without changing it means the next identical text is matched.
    - (b) Only explicit picks in the correction sheet count.

11. **A typed word that is found nowhere** (not in the USDA data and not in the user's foods).
    - **(a) Recommended:** keep the current rule. An item still gets a guess as long as half its words match a food, built from the words that are known.
    - (b) Any such word makes the item not found.

    How the two behave, from the prototype:

    | Input | (a) current rule | (b) not found |
    |---|---|---|
    | `zorbo bar` (unknown brand) | guess: Breakfast bar, NFS; 43 g; 162 kcal | not found ("zorbo") |
    | `kirkland protein bar` | guess: Nutrition bar (Snickers Marathon Protein Bar); 80 g; 332 kcal | not found ("kirkland") |
    | `leftover pizza` | guess: Pizza rolls; 85 g; 293 kcal | not found ("leftover") |
    | `grandmas meatloaf` | guess: Meat loaf, NS as to type of meat; 84 g; 170 kcal | not found ("grandma") |
    | `homemade soup` | guess: Soup, fish, homemade (Alaska Native); 100 g; 72 kcal | the same guess, because "homemade" happens to be in the data |
    | `1 cup homemade chicken soup` | guess: Soup, chicken; 245 g; 98 kcal | the same guess |

    Why (a): describing words such as "leftover" and "grandma's", and store brands, are common in real meal text. Under (b) each one blocks Save ("Fix 1 item") even when the guess is close, which costs taps against the speed target. Under (a) the "Guess" marker flags them, and one correction teaches the item's key. (b) would also be uneven: "homemade" passes only because a few Alaska Native foods use the word. The cost of (a) is that an unknown brand can be saved as a generic food if the user ignores the marker.

12. **The user's own foods against USDA foods** (5.4 key 2).
    - **(a) Recommended:** a user food comes first when it contains every typed word and the last word of its name was typed. "Turkey chili" wins for `chili`; "Peanut butter cookies" does not win for `butter`. This applies to custom foods and recipes, and to scanned Open Food Facts products only once the user has logged them, so a product that was merely scanned does not take over a common word like "yogurt".
    - (b) User foods always come first when they contain every typed word. This is simpler, but `butter` would give the cookies, and once they are logged that would even be a confident match.
    - (c) No special treatment. `2 servings chili` would then give "Chili, NFS", because the user's "Turkey chili" has the extra word "turkey".

### 14.3 Clarified during the build

In these places the document was silent or two of its rules disagreed. The lead settled them on 2026-11-13 while building the parser, and they are written into the sections named. None changes a worked example. Bart can overrule any of them. Only the ones a user would notice are listed.

- Leading filler is dropped whether or not an amount was typed, but never from the user's own names: `I had my oatmeal` finds the alias "my oatmeal" (2.3, 2.6 rule 1, 6.1).
- A period after a unit word ends the sentence unless the word is read as a unit there: `I ate a candy bar. Coffee with milk.` is two sentences (2.2).
- A product name with a size in it, such as "Coca-Cola 330ml", does not stop `330ml milk` being read as 330 ml of milk (2.1, 2.3).
- `xl` is read as "extra large" (4.3).
- `G` means grams, `patties` is the plural of patty, and abbreviations such as `pc` take only `s` (4.1).
- `eggs 2x` is read like `eggs x2` (2.6 rule 4, 3.2).
- Compound amounts can chain (`1 cup 2 tbsp 1 tsp`), but only with plain numbers, not word numbers (2.6 rule 3).
- Stray punctuation such as a lone `-` is ignored and never becomes a food word (2.1).
- Straight apostrophes are removed like curly ones, and `2-percent milk` is 2% milk, not a quantity of 2, because a hyphen between a digit and a letter becomes a space (2.1).
- An item with neither food words nor an amount, such as `some` or a lone `a`, gives no line, so `vitamin a` gives one line; an amount with no food is still not found (2.6 rule 5, 8.1).
- `2 large cups and a half milk` is read like `2 cups and a half milk` (2.4).
- The plural rule for words ending in "ie" and "ies": berries and berry meet, pies becomes pie, cookie and cookies meet (5.2 step 6).
- Synonyms also match plurals, such as `donuts` and `burgers` (5.3).
- The search box in the correction sheet uses synonyms, typo correction and the user's own foods, as matching does (5.7).
- The unit shown for a default or a portion is the portion's label without its amount ("tbsp", "cup, cooked") (4.4, 4.6).
- Typed "serving" on a food with no serving portion keeps the unit as typed, is not marked "Assumed", and weighs what the default weighs (4.5).
- A bare count shows the size word as its unit only when a portion with that size was found (4.5).
- `oz` on a user food is a fluid ounce when the food has a "fl oz" portion; otherwise it is a weight ounce, and on a food measured in ml it falls back to the default amount (4.2).
- The antipasto food gets 1 cup as its default, because its two "Quantity not specified" labels are not the exact default label (4.4).
- The portion pickers hide every label that starts with "Quantity not specified" (4.4, 8.3, 13).
- A learned match's key leaves out the negation cut and synonyms, so `coffee without sugar` and `coffee` have different keys (7.1).
- An item with no amount whose words are all cut by negation gives no line: in `coffee with no sugar`, "no sugar" gives no line and cannot block Save. With an amount it is not found: `2 no sugar` (5.2 step 3, 8.1).
- A lone describing word after a separator is not handled specially: `coffee, black` reads "black" as its own item, which may match a food as a guess (12.1).
- A product name ending in a size or percentage still fits the typed words: a logged "Fage Greek yogurt 0%" comes first for `greek yogurt` (5.4 key 2).
- A user food with a base amount of zero or less is never matched (4.5).
- A default shows the portion its rule picked when that portion's amount is 1 ("1 leek"), and only otherwise a portion of the same weight ("1 small" for coffee) (4.6).
- A bare count compares the portion's word with the plural rule, so `2 cookies` uses a "1 cookie" portion (4.5 rule 2).
- Every user name of two or more words is kept whole, whatever words it contains: with a logged cached product "Big Mac", `big mac` is "big mac", not a large "mac". A one-word name gets no protection, so a recipe named "Bowl" does not stop `1 bowl of rice` (2.3).
- Negation is not applied inside the user's own names: with a food named "No sugar cola", `2 cans no sugar cola` finds that food (2.3, 5.2 step 3).
- A scanned product's name is protected only once the product has been logged, so a never logged "Large eggs" does not change what `2 large eggs` means (2.3).
- The unit picker in the correction sheet offers only amounts the text can express for that food: no grams or ounces for a user food with no weight, `fl oz` instead of `oz` where oz would mean fluid ounces, and a bare count or `serving` whenever they re-parse to the same food. A new amount goes right before the first food word (`I had toast` becomes `I had 2 slice toast`), a leftover `of` is removed when the new amount has no unit, and a change the text cannot express is refused. "Remove from meal" and a saved meal's multiplier are checked by re-parsing the same way (8.3).
- Backspacing an amount no longer loses a pick: a changed key suspends the pick while the user keeps editing that item, and the pick comes back if the key matches again. It is dropped when the user changes another item, when its item is deleted, or when the screen closes (9.1).
- Trailing spaces or tabs after a not found item at the end of the text keep it under the cursor, so typing `2 ` does not flash "Not found" (9.2).
- Alias and saved meal names are compared after the same clean-up as typed text, so an alias saved as "pb&j" expands for `pb and j`, and the two cannot be saved as different aliases (6.1).
- New synonyms: `skim milk` and `nonfat milk` find "Milk, fat free (skim)", `bbq` reads as "barbecue", and `cereal` finds "Cereal, ready-to-eat, NFS" except in `cooked cereal` and `cereal bar` (5.3).

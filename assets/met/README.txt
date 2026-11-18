2024 Compendium MET values for Daybook

What this is
  compendium_2024.csv is the table of MET values the cardio screens use to
  estimate calories: 1,111 activities from the 2024 Adult Compendium of
  Physical Activities, one row per line, sorted by code. Values unchanged.

Source and credit
  MET values from the 2024 Adult Compendium of Physical Activities
  (https://pacompendium.com). Herrmann SD, Willis EA, Ainsworth BE, Barreira
  TV, Hastert M, Kracht CL, Schuna JM Jr, Cai Z, Quan M, Tudor-Locke C,
  Whitt-Glover MC, Jacobs DR Jr. 2024 Adult Compendium of Physical
  Activities: A third update of the energy costs of human activities. J Sport
  Health Sci. 2024;13(1):6-12. doi:10.1016/j.jshs.2023.10.010.

  The website says the Adult Compendium is free to use for commercial
  purposes and asks that MET values are not changed and that activities with
  different MET levels are not combined. Daybook shows the values exactly as
  published, never blends two activities, and cites the Compendium in About.
  The terms are recorded in docs/data-sources.md.

Where the file came from
  The PDF linked from https://pacompendium.com/adult-compendium/:
  https://pacompendium.com/wp-content/uploads/2025/02/1_2024-adult-compendium_1_2024.pdf
  563,091 bytes, SHA-256
  ac30234b8f8f813837e282773cfcb3e0fe062334777c2f7b3213429c4fbc251c.
  Downloaded and read on 2026-11-17. The app itself never calls the website.
  This file is a snapshot, and the committed file is the pin.

What each row has
  code         the five digit Compendium code, as text ("01003")
  heading      the major heading ("Running", "Conditioning Exercise")
  met          the MET value as the PDF prints it ("9.3"; 18290 is "8.00")
  description  the activity description, as published
  min_mph      lowest speed in mph the description gives, or empty
  max_mph      highest speed in mph the description gives, or empty

Values unchanged
  MET values and descriptions are exactly as the PDF has them: nothing is
  rounded, merged, renamed or invented, spelling mistakes included. Only two
  things were done to the text: runs of spaces became one space, and a
  description that wraps onto a second line in the PDF is joined to the first
  with one space.

Speeds (min_mph, max_mph)
  Filled only for rows under the Running, Walking and Bicycling headings, and
  only where the description writes a speed in mph. The first speed written
  is the one read. The number is kept as written ("7", "6.7", "5.0").
    "6-6.3 mph", "5.0 to 5.2 mph", "5.5 -5.8 mph"   a range: min and max
    "6.7 mph", "7 mph", "4.5mph"                    one speed: min = max
    "less than 2.0 mph", "<10 mph"                  max only
    "greater than ...", ">20 mph"                   min only
  A pace in min/mile ("(10 min/mile)") or a speed in km/h ("(6.4 to 7.0
  km/h)") written beside the mph is ignored, not converted. No row has only a
  pace or only km/h; the build script would list one. A description with no
  speed ("Running, self-selected pace") has empty speed columns: no band is
  invented. Where a description gives two speeds the first is kept (01050 is
  "16-19 mph, racing/not drafting or >19 mph drafting" and is read as 16 to
  19). "Less than" and "greater than" keep the number as the end of the open
  range. That number is not part of the open band: "less than 2.0 mph"
  (17151) does not include 2.0, which belongs to "2.0 to 2.4 mph" (17152),
  and "<10 mph" (01010) does not include 10, which belongs to "10-11.9 mph"
  (01020). A band with both numbers includes both of its ends.
  Which rows form the speed bands of Running, Walking and Bicycling, and which
  row is each group's general entry, is chosen in lib/data/met_table.dart.

Left out, and why
  The PDF and the website's 22 heading pages list the same 1,111 codes.
  1,114 is the journal article's figure. The only other five digit codes in
  the PDF are two former codes named inside descriptions (11200 and 17120);
  they are not rows. No row was dropped by the script: it stops and names any
  line it cannot place, and there were none.

How to rebuild
  python -I tools/build_met_table.py
  The PDF is downloaded to build/met-cache/ (not committed) and the script
  refuses to go on unless its size and SHA-256 are exactly the ones above. It
  reads the PDF only with pdftotext (Git for Windows ships it; on Ubuntu it is
  poppler-utils), in -raw mode, because -layout puts some rows' MET values on
  the wrong code. python -I -m unittest discover -s tools runs the tests, which
  need neither the PDF nor pdftotext.

# Daybook. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

# Adds the iPhone home-screen widget (the app extension target "WeightWidget")
# to ios/Runner.xcodeproj. There is no Mac on hand, so this runs on GitHub's
# macOS runner (.github/workflows/ios-widget-target.yml), which uploads the
# changed project.pbxproj to commit. See docs/ios-widget.md.
#
# Run from anywhere on a Mac with the xcodeproj gem (it comes with CocoaPods):
#   ruby tools/ios/add_widget_target.rb
#
# Safe to run twice: if the target is already there it changes nothing.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../ios/Runner.xcodeproj', __dir__)
NAME = 'WeightWidget'
BUNDLE_ID = 'io.github.bartbasi.daybook.WeightWidget'
EMBED_PHASE = 'Embed Foundation Extensions'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.native_targets.find { |t| t.name == 'Runner' }
abort 'The project has no Runner target.' unless runner

if project.targets.any? { |t| t.name == NAME }
  puts "The #{NAME} target is already in the project. Nothing changed."
  exit 0
end

# A half-added target from an earlier failed run would leave these behind.
if project.main_group.children.any? { |c| c.display_name == NAME } ||
   runner.copy_files_build_phases.any? { |p| p.name == EMBED_PHASE }
  abort "Parts of #{NAME} are in the project but the target is not. " \
        'Restore ios/Runner.xcodeproj/project.pbxproj from git and run again.'
end

thin_binary = runner.shell_script_build_phases.find { |p| p.name == 'Thin Binary' }
abort "The Runner target has no Thin Binary phase." unless thin_binary

runner_group = project.main_group.children.find { |c| c.display_name == 'Runner' }
abort 'The project has no Runner group.' unless runner_group

# Files. Paths are relative to their group, and the group to ios/.
group = project.main_group.new_group(NAME, NAME)
swift_file = group.new_reference('WeightWidget.swift')
group.new_reference('Info.plist')
group.new_reference('WeightWidget.entitlements')
runner_group.new_reference('Runner.entitlements')

# The extension target.
target = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
project.targets << target
target.name = NAME
target.product_name = NAME
target.product_type = Xcodeproj::Constants::PRODUCT_TYPE_UTI[:app_extension]
target.product_reference =
  project.products_group.new_product_ref_for_target(NAME, :app_extension)

# One configuration for each of the Runner's (Debug, Release, Profile), on the
# same Flutter xcconfig, so FLUTTER_BUILD_NAME and FLUTTER_BUILD_NUMBER (the
# app's version) are the extension's version too. The deployment target and
# device family come from the project, as for the Runner.
config_list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
config_list.default_configuration_is_visible = '0'
config_list.default_configuration_name = 'Release'
target.build_configuration_list = config_list
runner.build_configurations.each do |runner_config|
  config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  config.name = runner_config.name
  config.base_configuration_reference = runner_config.base_configuration_reference
  settings = {
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CODE_SIGN_ENTITLEMENTS' => "#{NAME}/#{NAME}.entitlements",
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks',
    ],
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SKIP_INSTALL' => 'YES',
    'VERSIONING_SYSTEM' => 'apple-generic',
  }
  %w[SWIFT_VERSION SWIFT_OPTIMIZATION_LEVEL].each do |key|
    value = runner_config.build_settings[key]
    settings[key] = value if value
  end
  config.build_settings = settings
  config_list.build_configurations << config
end

[
  Xcodeproj::Project::Object::PBXSourcesBuildPhase,
  Xcodeproj::Project::Object::PBXFrameworksBuildPhase,
  Xcodeproj::Project::Object::PBXResourcesBuildPhase,
].each { |phase_class| target.build_phases << project.new(phase_class) }
target.add_file_references([swift_file])

# The Runner: the same App Group entitlement, built after the extension, and
# the extension copied into Runner.app/PlugIns.
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner.add_dependency(target)

embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed.name = EMBED_PHASE
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
embed_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
embed_file.file_ref = target.product_reference
embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
embed.files << embed_file
# Before Flutter's Thin Binary script, or Xcode reports a dependency cycle.
runner.build_phases.insert(runner.build_phases.index(thin_binary), embed)

project.save

puts "Added the #{NAME} target (#{BUNDLE_ID})."
puts "Runner build phases: #{runner.build_phases.map(&:display_name).join(', ')}"
puts "#{NAME} configurations: #{target.build_configurations.map(&:name).join(', ')}"

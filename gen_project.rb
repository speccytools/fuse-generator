#!/usr/bin/env ruby
# gen_project.rb: Generate FuseGenerator.xcodeproj containing two Quick Look
# app extensions (FuseQLThumbnail, FuseQLPreview) that share the libspectrum
# + JWSpectrumScreen + LibspectrumSCRExtractor source base in this repo.
#
# Run from this directory:  ruby gen_project.rb
# Prerequisite:             gem install xcodeproj

require 'xcodeproj'

PROJECT_PATH = File.expand_path('FuseGenerator.xcodeproj', __dir__)
PROJECT_DIR  = File.expand_path(__dir__)

LIBSPEC_SOURCES = %w[
  buffer.c bzip2.c creator.c crypto.c csw.c dck.c ide.c libspectrum.c
  memory.c microdrive.c mmc.c plusd.c pzx_read.c rzx.c sna.c snapshot.c
  snp.c sp.c symbol_table.c szx.c tap.c tape.c tape_block.c timings.c
  tzx_read.c tzx_write.c utilities.c warajevo_read.c wav.c z80.c z80em.c
  zip.c zlib.c zxs.c
]
MYGLIB_SOURCES   = %w[garray.c ghash.c glock.c gslist.c]
GENERATED_INPUTS = %w[tape_accessors.txt snap_accessors.txt libspectrum.h.in]

File.delete(File.join(PROJECT_PATH, 'project.pbxproj')) rescue nil
Dir.rmdir(PROJECT_PATH) rescue nil

project = Xcodeproj::Project.new(PROJECT_PATH)
project.build_configurations.each do |c|
  c.build_settings.merge!({
    'ALWAYS_SEARCH_USER_PATHS' => 'NO',
    'CLANG_ENABLE_OBJC_ARC' => 'NO',
    'CLANG_WARN_BOOL_CONVERSION' => 'YES',
    'CLANG_WARN_CONSTANT_CONVERSION' => 'YES',
    'CLANG_WARN_EMPTY_BODY' => 'YES',
    'CLANG_WARN_ENUM_CONVERSION' => 'YES',
    'CLANG_WARN_INFINITE_RECURSION' => 'YES',
    'CLANG_WARN_INT_CONVERSION' => 'YES',
    'CLANG_WARN_SUSPICIOUS_MOVE' => 'YES',
    'CLANG_WARN_UNREACHABLE_CODE' => 'YES',
    'CLANG_WARN__DUPLICATE_METHOD_MATCH' => 'YES',
    'DEAD_CODE_STRIPPING' => 'YES',
    'ENABLE_STRICT_OBJC_MSGSEND' => 'YES',
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_NO_COMMON_BLOCKS' => 'YES',
    'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'YES',
    'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES',
    'GCC_WARN_UNDECLARED_SELECTOR' => 'YES',
    'GCC_WARN_UNINITIALIZED_AUTOS' => 'YES',
    'GCC_WARN_UNUSED_FUNCTION' => 'YES',
    'GCC_WARN_UNUSED_VARIABLE' => 'YES',
    'MACOSX_DEPLOYMENT_TARGET' => '12.0',
    'SDKROOT' => 'macosx',
  })
end
project.add_build_configuration('Deployment', :release)

# --- Groups -------------------------------------------------------------
main_group    = project.main_group
jwss_group    = main_group.new_group('JWSpectrumScreen', 'JWSpectrumScreen')
libspec_group = main_group.new_group('libspectrum', '../libspectrum')
myglib_group  = libspec_group.new_group('myglib', 'myglib')
thumb_group   = main_group.new_group('thumbnail', 'thumbnail')
preview_group = main_group.new_group('preview', 'preview')

# --- File references ----------------------------------------------------
gen_refs = {}
GENERATED_INPUTS.each { |n| gen_refs[n] = libspec_group.new_reference(n) }

ls_refs = LIBSPEC_SOURCES.map { |n| libspec_group.new_reference(n) }
mg_refs = MYGLIB_SOURCES.map { |n| myglib_group.new_reference(n) }

jwss_refs = []
%w[AttributeManager.c AttributeManager.h ColourMacros.c ColourMacros.h
   JWSpectrumScreen.h JWSpectrumScreen.m JWSpectrumScreenConstants.h
   PixelData.h].each do |name|
  jwss_refs << jwss_group.new_reference(name)
end

extractor_refs = []
%w[LibspectrumSCRExtractor.h LibspectrumSCRExtractor.m].each do |name|
  extractor_refs << main_group.new_reference(name)
end

thumb_refs = {
  source: thumb_group.new_reference('FuseThumbnailProvider.m'),
  plist:  thumb_group.new_reference('Info.plist'),
}
thumb_group.new_reference('FuseThumbnailProvider.h')
thumb_group.new_reference('thumbnail.entitlements')

preview_refs = {
  source: preview_group.new_reference('FusePreviewProvider.m'),
  plist:  preview_group.new_reference('Info.plist'),
}
preview_group.new_reference('FusePreviewProvider.h')
preview_group.new_reference('preview.entitlements')

# --- Build rules --------------------------------------------------------
def accessor_rule(project, pattern, script)
  rule = project.new(Xcodeproj::Project::Object::PBXBuildRule)
  rule.compiler_spec = 'com.apple.compilers.proxy.script'
  rule.file_patterns = pattern
  rule.file_type     = 'pattern.proxy'
  rule.is_editable   = '1'
  rule.script        = script
  rule.run_once_per_architecture = '0'
  rule
end

tape_accessors_rule = accessor_rule(project, '*ape_accessors.txt', <<~SH.strip)
  perl ${SRCROOT}/../libspectrum/tape_accessors.pl ${INPUT_FILE_PATH} > ${DERIVED_FILE_DIR}/${INPUT_FILE_BASE}.c
  perl ${SRCROOT}/../libspectrum/tape_set.pl ${INPUT_FILE_PATH} > ${DERIVED_FILE_DIR}/tape_set.c
SH
tape_accessors_rule.output_files = [
  '$(DERIVED_FILE_DIR)/$(INPUT_FILE_BASE).c',
  '$(DERIVED_FILE_DIR)/tape_set.c',
]

snap_accessors_rule = accessor_rule(project, '*nap_accessors.txt', <<~SH.strip)
  perl ${SRCROOT}/../libspectrum/accessor.pl ${INPUT_FILE_PATH} > ${DERIVED_FILE_DIR}/${INPUT_FILE_BASE}.c
SH
snap_accessors_rule.output_files = ['$(DERIVED_FILE_DIR)/$(INPUT_FILE_BASE).c']

libspec_h_rule = accessor_rule(project, '*ibspectrum.h.in', <<~SH.strip)
  LIBSPECTRUM_SRCDIR="${SRCROOT}/../libspectrum" perl -p ${SRCROOT}/generate.pl ${INPUT_FILE_PATH} > ${SRCROOT}/libspectrum.h
SH
libspec_h_rule.output_files = ['${SRCROOT}/libspectrum.h']

# --- Common target setup ------------------------------------------------
HEADER_SEARCH_PATHS = [
  '$(SRCROOT)',
  '$(SRCROOT)/JWSpectrumScreen',
  '$(SRCROOT)/../libspectrum',
]

shared_source_refs =
  [gen_refs['tape_accessors.txt'], gen_refs['snap_accessors.txt']] +
  ls_refs + mg_refs +
  jwss_refs.select { |r| r.path.end_with?('.c', '.m') } +
  extractor_refs.select { |r| r.path.end_with?('.m') }

rules = [tape_accessors_rule, snap_accessors_rule, libspec_h_rule]

def make_appex(project, name, provider_source, plist_ref,
               entitlements_path, frameworks, rules, shared_sources)
  target = project.new_target(:app_extension, name, :osx, '12.0', nil, :objc)
  target.add_build_configuration('Deployment', :release)

  target.build_configurations.each do |c|
    c.build_settings.merge!({
      'CLANG_ENABLE_OBJC_ARC' => 'NO',
      'CODE_SIGN_IDENTITY' => '-',
      'CODE_SIGN_STYLE' => 'Manual',
      'CODE_SIGN_ENTITLEMENTS' => entitlements_path,
      'COMBINE_HIDPI_IMAGES' => 'YES',
      'CURRENT_PROJECT_VERSION' => '1',
      'DEVELOPMENT_TEAM' => '',
      'HEADER_SEARCH_PATHS' => HEADER_SEARCH_PATHS,
      'INFOPLIST_FILE' => plist_ref.real_path.relative_path_from(Pathname.new(PROJECT_DIR)).to_s,
      'LD_RUNPATH_SEARCH_PATHS' => [
        '$(inherited)',
        '@executable_path/../../../../Frameworks',
        '@executable_path/../../../../../Frameworks',
      ],
      'LLVM_LTO' => 'YES',
      'MACOSX_DEPLOYMENT_TARGET' => '12.0',
      'MARKETING_VERSION' => '1.0',
      'OTHER_LDFLAGS' => %w[-lbz2 -lz],
      'PRODUCT_BUNDLE_IDENTIFIER' => "FuseXPreferences.quicklook.#{name.sub(/^FuseQL/, '').downcase}",
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'PROVISIONING_PROFILE_SPECIFIER' => '',
      'SKIP_INSTALL' => 'YES',
      'WRAPPER_EXTENSION' => 'appex',
    })
    if c.name == 'Debug'
      c.build_settings['GCC_OPTIMIZATION_LEVEL'] = '0'
      c.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
    end
  end

  rules.each { |r| target.build_rules << r }

  src_phase = target.source_build_phase
  src_phase.add_file_reference(provider_source)
  shared_sources.each { |ref| src_phase.add_file_reference(ref) }

  fw_phase = target.frameworks_build_phase
  frameworks.each do |framework_name|
    ref = project.frameworks_group.new_reference("System/Library/Frameworks/#{framework_name}.framework")
    ref.source_tree = 'SDKROOT'
    ref.name = "#{framework_name}.framework"
    fw_phase.add_file_reference(ref)
  end

  target
end

make_appex(project, 'FuseQLThumbnail',
           thumb_refs[:source], thumb_refs[:plist],
           'thumbnail/thumbnail.entitlements',
           %w[AppKit CoreFoundation CoreGraphics CoreServices
              Foundation ImageIO QuickLookThumbnailing],
           rules, shared_source_refs)

make_appex(project, 'FuseQLPreview',
           preview_refs[:source], preview_refs[:plist],
           'preview/preview.entitlements',
           %w[AppKit CoreFoundation CoreGraphics CoreServices
              Foundation ImageIO QuickLook QuickLookUI],
           rules, shared_source_refs)

project.save
puts "Wrote #{PROJECT_PATH}"

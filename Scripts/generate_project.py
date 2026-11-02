#!/usr/bin/env python3
"""Generate a dependency-free Xcode project using stable object identifiers."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
objects = {}

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def obj(key_name, isa, **fields):
    key = ident(key_name)
    objects[key] = dict(isa=isa, **fields)
    return key

def emit(value, depth=0):
    pad = '\t' * depth
    if isinstance(value, dict):
        return '{\n' + ''.join(f'{pad}\t{emit(k)} = {emit(v, depth + 1)};\n' for k, v in value.items()) + pad + '}'
    if isinstance(value, list):
        return '(\n' + ''.join(f'{pad}\t{emit(v, depth + 1)},\n' for v in value) + pad + ')'
    import json
    return json.dumps(str(value), ensure_ascii=True)

sources = []
builds = []
for path in sorted((ROOT / 'NovaEditor').glob('*.swift')):
    ref = obj('file:' + path.name, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=path.name, sourceTree='<group>')
    sources.append(ref)
    builds.append(obj('build:' + path.name, 'PBXBuildFile', fileRef=ref))
source_group = obj('sources', 'PBXGroup', children=sources, path='NovaEditor', sourceTree='<group>')
product = obj('app', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='NovaEditor.app', sourceTree='BUILT_PRODUCTS_DIR')
products = obj('products', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
main = obj('main', 'PBXGroup', children=[source_group, products], sourceTree='<group>')
phase = obj('source-phase', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0)
frameworks = obj('frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
resources = obj('resources', 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
project_configs, app_configs = [], []
for mode in ('Debug', 'Release'):
    project_configs.append(obj('project:' + mode, 'XCBuildConfiguration', name=mode, buildSettings={
        'CLANG_ENABLE_MODULES': 'YES', 'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
        'SWIFT_VERSION': '5.0', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym',
        'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O',
    }))
    app_configs.append(obj('app:' + mode, 'XCBuildConfiguration', name=mode, buildSettings={
        'PRODUCT_NAME': 'NovaEditor', 'PRODUCT_BUNDLE_IDENTIFIER': 'org.example.NovaEditor',
        'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '0.1.0',
        'GENERATE_INFOPLIST_FILE': 'YES', 'INFOPLIST_KEY_CFBundleDisplayName': 'NovaEditor',
        'INFOPLIST_KEY_LSApplicationCategoryType': 'public.app-category.video',
        'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES',
        'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations': 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad': 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
        'TARGETED_DEVICE_FAMILY': '1,2', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
        'SUPPORTS_MACCATALYST': 'NO', 'CODE_SIGN_STYLE': 'Manual',
        'SWIFT_EMIT_LOC_STRINGS': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
    }))
pc = obj('project-configs', 'XCConfigurationList', buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
ac = obj('app-configs', 'XCConfigurationList', buildConfigurations=app_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
target = obj('target', 'PBXNativeTarget', buildConfigurationList=ac, buildPhases=[phase, frameworks, resources], buildRules=[], dependencies=[], name='NovaEditor', productName='NovaEditor', productReference=product, productType='com.apple.product-type.application')
project = obj('project', 'PBXProject', attributes={'LastUpgradeCheck': '1640'}, buildConfigurationList=pc, compatibilityVersion='Xcode 14.0', developmentRegion='pt', hasScannedForEncodings=0, knownRegions=['pt', 'en', 'Base'], mainGroup=main, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target])
folder = ROOT / 'NovaEditor.xcodeproj'
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + emit(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project)) + '\n')
schemes = folder / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
(schemes / 'NovaEditor.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
   <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="NovaEditor.app" BlueprintName="NovaEditor" ReferencedContainer="container:NovaEditor.xcodeproj"/>
  </BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
  <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="NovaEditor.app" BlueprintName="NovaEditor" ReferencedContainer="container:NovaEditor.xcodeproj"/></BuildableProductRunnable>
 </LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f'Generated {folder.name}: {len(sources)} Swift sources')

#!/usr/bin/env python3
"""Generate the dependency-free Xcode project with deterministic object IDs."""
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
objects = {}

def oid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(name, body):
    objects[oid(name)] = body
    return oid(name)

def refs(items):
    return "(" + ", ".join(items) + ",)" if items else "()"

def file(path, kind):
    return add(path, f'{{isa = PBXFileReference; lastKnownFileType = {kind}; path = "{path}"; sourceTree = "<group>"; }}')

config = file("Config.xcconfig", "text.xcconfig")
groups, targets, products, attributes = [], [], [], []
for name, folder, product_type in [
    ("TinkOn", "TinkOn", "com.apple.product-type.application"),
    ("TinkOnTests", "TinkOnTests", "com.apple.product-type.bundle.unit-test"),
    ("TinkOnUITests", "TinkOnUITests", "com.apple.product-type.bundle.ui-testing"),
]:
    files, source_builds, resource_builds = [], [], []
    for path in sorted((root / folder).iterdir()):
        kinds = {".swift": "sourcecode.swift", ".plist": "text.plist.xml", ".xcprivacy": "text.xml", ".storyboard": "file.storyboard", ".xcassets": "folder.assetcatalog"}
        if path.suffix not in kinds:
            continue
        ref = file(path.name, kinds[path.suffix])
        # Filenames are unique across our targets.
        files.append(ref)
        if path.suffix == ".swift":
            source_builds.append(add(f"build-{name}-{path.name}", f"{{isa = PBXBuildFile; fileRef = {ref}; }}"))
        elif path.suffix != ".plist":
            resource_builds.append(add(f"build-{name}-{path.name}", f"{{isa = PBXBuildFile; fileRef = {ref}; }}"))
    groups.append(add(f"group-{name}", f'{{isa = PBXGroup; children = {refs(files)}; path = "{folder}"; sourceTree = "<group>"; }}'))
    phases = [
        add(f"sources-{name}", f"{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(source_builds)}; runOnlyForDeploymentPostprocessing = 0; }}"),
        add(f"frameworks-{name}", "{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }"),
        add(f"resources-{name}", f"{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs(resource_builds)}; runOnlyForDeploymentPostprocessing = 0; }}"),
    ]
    is_app = name == "TinkOn"
    extension, kind = ("app", "wrapper.application") if is_app else ("xctest", "wrapper.cfbundle")
    product = add(f"product-{name}", f'{{isa = PBXFileReference; explicitFileType = {kind}; includeInIndex = 0; path = {name}.{extension}; sourceTree = BUILT_PRODUCTS_DIR; }}')
    products.append(product)
    configs = []
    for mode in ["Debug", "Release"]:
        settings = {
            "PRODUCT_NAME": '"$(TARGET_NAME)"', "SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "TARGETED_DEVICE_FAMILY": '"1,2"', "SDKROOT": "iphoneos", "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
            "SWIFT_EMIT_LOC_STRINGS": "YES", "CODE_SIGN_STYLE": "Automatic",
            "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"' if mode == "Debug" else '"-O"',
        }
        if is_app:
            settings.update({"PRODUCT_BUNDLE_IDENTIFIER": '"$(TINKON_BUNDLE_ID)"', "INFOPLIST_FILE": '"TinkOn/Info.plist"',
                             "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "MARKETING_VERSION": "1.1.1", "CURRENT_PROJECT_VERSION": "13",
                             "ENABLE_PREVIEWS": "YES"})
        else:
            settings.update({"PRODUCT_BUNDLE_IDENTIFIER": f'"$(TINKON_BUNDLE_ID).{name}"', "GENERATE_INFOPLIST_FILE": "YES"})
            if name == "TinkOnTests":
                settings.update({"BUNDLE_LOADER": '"$(TEST_HOST)"', "TEST_HOST": '"$(BUILT_PRODUCTS_DIR)/TinkOn.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TinkOn"'})
            else:
                settings["TEST_TARGET_NAME"] = "TinkOn"
        settings_text = " ".join(f"{key} = {value};" for key, value in settings.items())
        configs.append(add(f"config-{name}-{mode}", f'{{isa = XCBuildConfiguration; baseConfigurationReference = {config}; buildSettings = {{ {settings_text} }}; name = {mode}; }}'))
    config_list = add(f"config-list-{name}", f"{{isa = XCConfigurationList; buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}")
    dependencies = []
    if not is_app:
        proxy = add(f"proxy-{name}", f'{{isa = PBXContainerItemProxy; containerPortal = {oid("project")}; proxyType = 1; remoteGlobalIDString = {oid("target-TinkOn")}; remoteInfo = TinkOn; }}')
        dependencies.append(add(f"dependency-{name}", f'{{isa = PBXTargetDependency; target = {oid("target-TinkOn")}; targetProxy = {proxy}; }}'))
    target = add(f"target-{name}", f'{{isa = PBXNativeTarget; buildConfigurationList = {config_list}; buildPhases = {refs(phases)}; buildRules = (); dependencies = {refs(dependencies)}; name = {name}; productName = {name}; productReference = {product}; productType = "{product_type}"; }}')
    targets.append(target)
    attributes.append(f'{target} = {{CreatedOnToolsVersion = 26.3; {"" if is_app else "TestTargetID = " + oid("target-TinkOn") + ";"} }};')

product_group = add("products", f'{{isa = PBXGroup; children = {refs(products)}; name = Products; sourceTree = "<group>"; }}')
main_group = add("main-group", f'{{isa = PBXGroup; children = {refs([config] + groups + [product_group])}; sourceTree = "<group>"; }}')
configs = []
for mode in ["Debug", "Release"]:
    settings = 'CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; ENABLE_TESTABILITY = YES; GCC_C_LANGUAGE_STANDARD = gnu17;'
    settings += ' DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ONLY_ACTIVE_ARCH = YES;' if mode == "Debug" else ' DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; VALIDATE_PRODUCT = YES;'
    configs.append(add(f"project-config-{mode}", f"{{isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {mode}; }}"))
config_list = add("project-config-list", f"{{isa = XCConfigurationList; buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}")
project = add("project", f'{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 2630; LastUpgradeCheck = 2630; TargetAttributes = {{ {" ".join(attributes)} }}; }}; buildConfigurationList = {config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = {refs(targets)}; }}')
project_dir = root / "TinkOn.xcodeproj"
project_dir.mkdir(exist_ok=True)
body = "\n".join(f"\t\t{key} = {value};" for key, value in objects.items())
(project_dir / "project.pbxproj").write_text(f"// !$*UTF8*$!\n{{\n\tarchiveVersion = 1;\n\tclasses = {{}};\n\tobjectVersion = 56;\n\tobjects = {{\n{body}\n\t}};\n\trootObject = {project};\n}}\n")
scheme_dir = project_dir / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
def reference(name):
    ext = "app" if name == "TinkOn" else "xctest"
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid("target-" + name)}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:TinkOn.xcodeproj"/>'
tests = "".join(f'<TestableReference skipped="NO">{reference(name)}</TestableReference>' for name in ["TinkOnTests", "TinkOnUITests"])
(scheme_dir / "TinkOn.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference("TinkOn")}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{tests}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("TinkOn")}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("TinkOn")}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(project_dir)

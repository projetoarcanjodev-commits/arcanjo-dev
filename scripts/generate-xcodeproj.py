#!/usr/bin/env python3
"""Regenerate the minimal native Xcode project from the Swift source tree."""
from hashlib import sha1
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "ArcanjoDev.xcodeproj"
APP_TARGET = sha1(b"target:ArcanjoDev").hexdigest()[:24].upper()
TEST_TARGET = sha1(b"target:ArcanjoDevTests").hexdigest()[:24].upper()
PROJECT_ID = sha1(b"project:ArcanjoDev").hexdigest()[:24].upper()

# Pinned to the APIs used by MLX Swift LM 3.31.4 and its published SPM manifest.
# Format: (package URL, exact semver, product names)
PACKAGES = [
    ("https://github.com/ml-explore/mlx-swift-lm", "3.31.4", ["MLXLLM", "MLXLMCommon", "MLXHuggingFace"]),
    ("https://github.com/ml-explore/mlx-swift", "0.31.4", ["MLX"]),
    ("https://github.com/huggingface/swift-huggingface", "0.9.0", ["HuggingFace"]),
    ("https://github.com/huggingface/swift-transformers", "1.3.0", ["Tokenizers"]),
]


def uid(name: str) -> str:
    return sha1(name.encode("utf-8")).hexdigest()[:24].upper()


def q(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def section(title: str, entries: list[str]) -> str:
    if not entries:
        return f"/* Begin {title} section */\n/* End {title} section */"
    return f"/* Begin {title} section */\n" + "\n".join(entries) + f"\n/* End {title} section */"


app_sources = sorted((ROOT / "ArcanjoDev").rglob("*.swift"))
test_sources = sorted((ROOT / "ArcanjoDevTests").rglob("*.swift"))
objects: list[str] = []
file_refs: list[str] = []
app_build_files: list[str] = []
test_build_files: list[str] = []

for source in app_sources + test_sources:
    rel_root = source.relative_to(ROOT)
    source_root = ROOT / ("ArcanjoDev" if source in app_sources else "ArcanjoDevTests")
    source_path = source.relative_to(source_root).as_posix()
    ref = uid(f"file:{rel_root.as_posix()}")
    file_refs.append(f"\t\t{ref} /* {source.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(source_path)}; sourceTree = \"<group>\"; }};")
    build = uid(f"build:{rel_root.as_posix()}")
    objects.append(f"\t\t{build} /* {source.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {source.name} */; }};")
    (app_build_files if source in app_sources else test_build_files).append(f"\t\t\t\t{build} /* {source.name} in Sources */, ")

app_refs = [uid(f"file:{p.relative_to(ROOT).as_posix()}") for p in app_sources]
test_refs = [uid(f"file:{p.relative_to(ROOT).as_posix()}") for p in test_sources]
app_group = uid("group:ArcanjoDev")
test_group = uid("group:ArcanjoDevTests")
products_group = uid("group:Products")
main_group = uid("group:Main")
app_product = uid("product:ArcanjoDev.app")
test_product = uid("product:ArcanjoDevTests.xctest")
app_sources_phase = uid("phase:ArcanjoDev:Sources")
app_frameworks_phase = uid("phase:ArcanjoDev:Frameworks")
app_resources_phase = uid("phase:ArcanjoDev:Resources")
test_sources_phase = uid("phase:ArcanjoDevTests:Sources")
test_frameworks_phase = uid("phase:ArcanjoDevTests:Frameworks")
test_resources_phase = uid("phase:ArcanjoDevTests:Resources")
app_debug = uid("config:ArcanjoDev:Debug")
app_release = uid("config:ArcanjoDev:Release")
test_debug = uid("config:ArcanjoDevTests:Debug")
test_release = uid("config:ArcanjoDevTests:Release")
project_debug = uid("config:Project:Debug")
project_release = uid("config:Project:Release")
app_config_list = uid("configlist:ArcanjoDev")
test_config_list = uid("configlist:ArcanjoDevTests")
project_config_list = uid("configlist:Project")
proxy_id = uid("proxy:ArcanjoDevTests->ArcanjoDev")
dependency_id = uid("dependency:ArcanjoDevTests->ArcanjoDev")

package_refs: list[str] = []
package_deps: list[str] = []
package_build_files: list[str] = []
for package_url, minimum_version, products in PACKAGES:
    package_id = uid(f"package:{package_url}")
    package_refs.append(f"\t\t{package_id} /* XCRemoteSwiftPackageReference \"{package_url.rsplit('/',1)[-1]}\" */ = {{isa = XCRemoteSwiftPackageReference; repositoryURL = {q(package_url)}; requirement = {{kind = exactVersion; version = {q(minimum_version)}; }}; }};")
    for product in products:
        dep_id = uid(f"package-product:{package_url}:{product}")
        build_id = uid(f"package-build:{package_url}:{product}")
        package_deps.append(f"\t\t{dep_id} /* {product} */ = {{isa = XCSwiftPackageProductDependency; package = {package_id} /* XCRemoteSwiftPackageReference */; productName = {q(product)}; }};")
        package_build_files.append(f"\t\t{build_id} /* {product} in Frameworks */ = {{isa = PBXBuildFile; productRef = {dep_id} /* {product} */; }};")

objects.extend(file_refs)
objects.extend(package_refs)
objects.extend(package_deps)
objects.extend(package_build_files)
objects.extend([
    f"\t\t{app_group} /* ArcanjoDev */ = {{isa = PBXGroup; children = (" + "".join(f"\n\t\t\t\t{ref} /* {p.name} */," for ref, p in zip(app_refs, app_sources)) + f"\n\t\t\t); path = ArcanjoDev; sourceTree = \"<group>\"; }};",
    f"\t\t{test_group} /* ArcanjoDevTests */ = {{isa = PBXGroup; children = (" + "".join(f"\n\t\t\t\t{ref} /* {p.name} */," for ref, p in zip(test_refs, test_sources)) + f"\n\t\t\t); path = ArcanjoDevTests; sourceTree = \"<group>\"; }};",
    f"\t\t{products_group} /* Products */ = {{isa = PBXGroup; children = ( {app_product} /* ArcanjoDev.app */, {test_product} /* ArcanjoDevTests.xctest */, ); name = Products; sourceTree = \"<group>\"; }};",
    f"\t\t{main_group} = {{isa = PBXGroup; children = ( {app_group} /* ArcanjoDev */, {test_group} /* ArcanjoDevTests */, {products_group} /* Products */, ); sourceTree = \"<group>\"; }};",
    f"\t\t{app_product} /* ArcanjoDev.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ArcanjoDev.app; sourceTree = BUILT_PRODUCTS_DIR; }};",
    f"\t\t{test_product} /* ArcanjoDevTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ArcanjoDevTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};",
    f"\t\t{app_sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n" + "\n".join(app_build_files) + "\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };",
    f"\t\t{test_sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n" + "\n".join(test_build_files) + "\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };",
    f"\t\t{app_frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (" + " ".join(f"{uid(f'package-build:{url}:{product}')} /* {product} in Frameworks */," for url, _, products in PACKAGES for product in products) + "); runOnlyForDeploymentPostprocessing = 0; };",
    f"\t\t{test_frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};",
    f"\t\t{app_resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};",
    f"\t\t{test_resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};",
    f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{isa = PBXContainerItemProxy; containerPortal = {PROJECT_ID} /* Project object */; proxyType = 1; remoteGlobalIDString = {APP_TARGET}; remoteInfo = ArcanjoDev; }};",
    f"\t\t{dependency_id} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {APP_TARGET} /* ArcanjoDev */; targetProxy = {proxy_id} /* PBXContainerItemProxy */; }};",
    f"\t\t{APP_TARGET} /* ArcanjoDev */ = {{isa = PBXNativeTarget; buildConfigurationList = {app_config_list} /* Build configuration list for PBXNativeTarget \"ArcanjoDev\" */; buildPhases = ( {app_sources_phase} /* Sources */, {app_frameworks_phase} /* Frameworks */, {app_resources_phase} /* Resources */, ); buildRules = (); dependencies = (); name = ArcanjoDev; packageProductDependencies = (" + " ".join(uid(f"package-product:{url}:{product}") + f" /* {product} */," for url, _, products in PACKAGES for product in products) + f" ); productName = ArcanjoDev; productReference = {app_product} /* ArcanjoDev.app */; productType = \"com.apple.product-type.application\"; }};",
    f"\t\t{TEST_TARGET} /* ArcanjoDevTests */ = {{isa = PBXNativeTarget; buildConfigurationList = {test_config_list} /* Build configuration list for PBXNativeTarget \"ArcanjoDevTests\" */; buildPhases = ( {test_sources_phase} /* Sources */, {test_frameworks_phase} /* Frameworks */, {test_resources_phase} /* Resources */, ); buildRules = (); dependencies = ( {dependency_id} /* PBXTargetDependency */, ); name = ArcanjoDevTests; packageProductDependencies = (); productName = ArcanjoDevTests; productReference = {test_product} /* ArcanjoDevTests.xctest */; productType = \"com.apple.product-type.bundle.unit-test\"; }};",
    f"\t\t{project_config_list} /* Build configuration list for PBXProject */ = {{isa = XCConfigurationList; buildConfigurations = ( {project_debug} /* Debug */, {project_release} /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};",
    f"\t\t{app_config_list} /* Build configuration list for PBXNativeTarget \"ArcanjoDev\" */ = {{isa = XCConfigurationList; buildConfigurations = ( {app_debug} /* Debug */, {app_release} /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};",
    f"\t\t{test_config_list} /* Build configuration list for PBXNativeTarget \"ArcanjoDevTests\" */ = {{isa = XCConfigurationList; buildConfigurations = ( {test_debug} /* Debug */, {test_release} /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};",
])

project_targets = f"{APP_TARGET} /* ArcanjoDev */, {TEST_TARGET} /* ArcanjoDevTests */"
objects.append(f"\t\t{PROJECT_ID} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{{APP_TARGET} = {{CreatedOnToolsVersion = 16.0; ProvisioningStyle = Automatic; }}; {TEST_TARGET} = {{CreatedOnToolsVersion = 16.0; ProvisioningStyle = Automatic; TestTargetID = {APP_TARGET}; }}; }}; }}; buildConfigurationList = {project_config_list} /* Build configuration list for PBXProject */; compatibilityVersion = \"Xcode 15.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base,); mainGroup = {main_group}; packageReferences = (" + " ".join(uid(f"package:{url}") + f" /* XCRemoteSwiftPackageReference \"{url.rsplit('/',1)[-1]}\" */," for url, _, _ in PACKAGES) + f" ); productRefGroup = {products_group} /* Products */; projectDirPath = \"\"; projectRoot = \"\"; targets = ( {project_targets}, ); }};")

project_settings = """
		PRODUCT_NAME = "$(TARGET_NAME)";
		IPHONEOS_DEPLOYMENT_TARGET = 17.0;
		SDKROOT = iphoneos;
		SWIFT_VERSION = 5.0;
		SWIFT_STRICT_CONCURRENCY = targeted;
		TARGETED_DEVICE_FAMILY = 1;
		SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
		ENABLE_PREVIEWS = YES;
""".strip()
app_settings = """
		CODE_SIGN_STYLE = Automatic;
		GENERATE_INFOPLIST_FILE = YES;
		INFOPLIST_KEY_CFBundleDisplayName = "Arcanjo Dev";
		INFOPLIST_KEY_UIFileSharingEnabled = YES;
		INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES;
		INFOPLIST_KEY_UILaunchScreen_Generation = YES;
		PRODUCT_BUNDLE_IDENTIFIER = com.arcanjodev.app;
		SWIFT_EMIT_LOC_STRINGS = YES;
""".strip()
test_settings = """
		BUNDLE_LOADER = "$(TEST_HOST)";
		GENERATE_INFOPLIST_FILE = YES;
		PRODUCT_BUNDLE_IDENTIFIER = com.arcanjodev.app.tests;
		TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ArcanjoDev.app/ArcanjoDev";
""".strip()

for config_id, name in [(project_debug, "Debug"), (project_release, "Release")]:
    extra = "\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;" if name == "Debug" else "\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";"
    objects.append(f"\t\t{config_id} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{{project_settings}\n\t\t{extra}\n\t\t}}; name = {name}; }};")
for config_id, name in [(app_debug, "Debug"), (app_release, "Release")]:
    extra = "\t\tENABLE_TESTABILITY = YES;\n\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";" if name == "Debug" else "\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";"
    objects.append(f"\t\t{config_id} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{{project_settings}\n\t\t{app_settings}\n\t\t{extra}\n\t\t}}; name = {name}; }};")
for config_id, name in [(test_debug, "Debug"), (test_release, "Release")]:
    extra = "\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";" if name == "Debug" else "\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";"
    objects.append(f"\t\t{config_id} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{{project_settings}\n\t\t{test_settings}\n\t\t{extra}\n\t\t}}; name = {name}; }};")

pbx = """// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 56;
	objects = {
""" + "\n".join(objects) + "\n\t};\n\trootObject = " + PROJECT_ID + " /* Project object */;\n}\n"
PROJECT.mkdir(parents=True, exist_ok=True)
(PROJECT / "project.pbxproj").write_text(pbx)

scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{APP_TARGET}" BuildableName="ArcanjoDev.app" BlueprintName="ArcanjoDev" ReferencedContainer="container:ArcanjoDev.xcodeproj" /></BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger" selectedLauncherIdentifier="Xcode.Debugger.Launcher" shouldUseLaunchSchemeArgsEnv="YES" shouldAutocreateTestPlan="YES"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{TEST_TARGET}" BuildableName="ArcanjoDevTests.xctest" BlueprintName="ArcanjoDevTests" ReferencedContainer="container:ArcanjoDev.xcodeproj" /></TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.Debugger.Debugger" selectedLauncherIdentifier="Xcode.Debugger.Launcher" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{APP_TARGET}" BuildableName="ArcanjoDev.app" BlueprintName="ArcanjoDev" ReferencedContainer="container:ArcanjoDev.xcodeproj" /></BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{APP_TARGET}" BuildableName="ArcanjoDev.app" BlueprintName="ArcanjoDev" ReferencedContainer="container:ArcanjoDev.xcodeproj" /></BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug" />
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES" />
</Scheme>
'''
(scheme_dir / "ArcanjoDev.xcscheme").write_text(scheme)
print(f"Generated {PROJECT / 'project.pbxproj'} ({len(app_sources)} app sources, {len(test_sources)} test sources, {len(PACKAGES)} packages)")

DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include YuTimeShrinkBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YuTimeShrink
YuTimeShrink_FILES = $(wildcard Hooks/*.xm Sources/*.m)
YuTimeShrink_CFLAGS = -fobjc-arc -I./Headers -I./Sources
YuTimeShrink_FRAMEWORKS = UIKit Foundation CoreFoundation
YuTimeShrink_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += YuTimeShrinkPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk

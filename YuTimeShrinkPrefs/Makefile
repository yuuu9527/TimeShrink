include ../YuTimeShrinkBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = YuTimeShrinkPrefs
YuTimeShrinkPrefs_FILES = $(wildcard *.m)
YuTimeShrinkPrefs_CFLAGS = -fobjc-arc -I../Sources
YuTimeShrinkPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
YuTimeShrinkPrefs_PRIVATE_FRAMEWORKS = Preferences
YuTimeShrinkPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

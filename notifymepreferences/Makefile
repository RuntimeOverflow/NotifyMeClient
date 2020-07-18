TARGET = iphone:clang:13.4:10.0
ARCHS = armv7 armv7s arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = NotifyMePreferences

NotifyMePreferences_FILES = $(wildcard *.m)
NotifyMePreferences_INSTALL_PATH = /Library/PreferenceBundles
NotifyMePreferences_FRAMEWORKS = UIKit
NotifyMePreferences_PRIVATE_FRAMEWORKS = Preferences
NotifyMePreferences_LIBRARIES = applist
NotifyMePreferences_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/NotifyMePreferences.plist$(ECHO_END)

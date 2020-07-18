INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_DEVICE_IP=192.168.63.58

TARGET = iphone:clang:13.4:10.0
ARCHS = armv7 armv7s arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NotifyMe

NotifyMe_FILES = $(wildcard *.xm *.m)
NotifyMe_CFLAGS = -fobjc-arc
NotifyMe_PRIVATE_FRAMEWORKS += UserNotificationsKit UserNotificationsUIKit

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += notifymepreferences
include $(THEOS_MAKE_PATH)/aggregate.mk

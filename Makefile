include $(TOPDIR)/rules.mk

# Read version from VERSION file
PKG_VERSION:=$(shell cat $(CURDIR)/VERSION 2>/dev/null || echo "1.0.0.0")

PKG_NAME:=luci-app-camtools
PKG_RELEASE:=1
PKG_MAINTAINER:=CamTools Team
PKG_LICENSE:=Apache-2.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-camtools
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for CamTools_wrt
  DEPENDS:=+curl +luci-base
  PKGARCH:=all
endef

define Package/luci-app-camtools/description
  LuCI web interface for CamTools - Campus Network Auto Login Tool.
  
  Automatic campus network authentication service for OpenWrt.
  Monitors network connectivity and automatically authenticates
  with campus network portal when internet access is lost.
  
  Features:
  - Automatic network connectivity monitoring
  - Auto-login on connection loss
  - LuCI web interface for easy configuration
  - Real-time status monitoring
  - Detailed logging with web viewer
  
  Pure shell script implementation - no compilation required!
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./camtools.sh $(PKG_BUILD_DIR)/
	$(CP) ./files $(PKG_BUILD_DIR)/
	$(CP) ./luasrc $(PKG_BUILD_DIR)/
endef

define Build/Configure
	# No configuration needed for shell script
endef

define Build/Compile
	# No compilation needed for shell script
	# Force package creation
	true
endef

define Package/luci-app-camtools/install
	# Install main shell script
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/camtools.sh $(1)/usr/bin/camtools.sh
	
	# Install init script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/camtools.init $(1)/etc/init.d/camtools
	
	# Install default configuration
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/files/camtools.config $(1)/etc/config/camtools
	
	# Install version file
	$(INSTALL_DIR) $(1)/etc/camtools
	echo "$(PKG_VERSION)" > $(1)/etc/camtools/version
	
	# Install LuCI controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luasrc/controller/camtools.lua \
		$(1)/usr/lib/lua/luci/controller/
	
	# Install LuCI model (with subdirectory)
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/camtools
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luasrc/model/cbi/camtools/settings.lua \
		$(1)/usr/lib/lua/luci/model/cbi/camtools/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luasrc/model/cbi/camtools/logs.lua \
		$(1)/usr/lib/lua/luci/model/cbi/camtools/
	
	# Install LuCI views
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/camtools
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luasrc/view/camtools/*.htm \
		$(1)/usr/lib/lua/luci/view/camtools/
endef

define Package/luci-app-camtools/conffiles
/etc/config/camtools
endef

define Package/luci-app-camtools/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	echo "Enabling camtools service..."
	/etc/init.d/camtools enable
	echo "CamTools installed successfully!"
	echo "Configure via LuCI: Services -> 校园网登录"
	echo "Or edit /etc/config/camtools"
}
exit 0
endef

define Package/luci-app-camtools/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	echo "Stopping camtools service..."
	/etc/init.d/camtools stop
	/etc/init.d/camtools disable
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-camtools))

#!/system/bin/sh
echo "[stage] uid=$(id -u) enforce=$(getenforce)"
echo "[stage] running area_patch"
/data/local/tmp/area_patch
RC=$?
echo "[stage] area_patch rc=$RC"
for k in persist.sys.support_view_mishadow persist.sys.support_view_smoothcorner persist.sys.support_window_mishadow persist.sys.support_window_smoothcorner persist.sys.device.freeform_hwui_corner_supported persist.sys.device.freeform_hwui_shadow_supported; do
  echo "[stage] $k = $(getprop $k)"
done
echo "[stage] PROPS_DONE"

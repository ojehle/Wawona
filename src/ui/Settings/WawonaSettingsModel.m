#import "WawonaSettingsModel.h"

@implementation WawonaSettingItem
+ (instancetype)itemWithTitle:(NSString *)title
                          key:(NSString *)key
                         type:(WawonaSettingType)type
                      default:(id)def
                         desc:(NSString *)desc {
  WawonaSettingItem *item = [[WawonaSettingItem alloc] init];
  item.title = title;
  item.key = key;
  item.type = type;
  item.defaultValue = def;
  item.desc = desc;
  return item;
}
@end

@implementation WawonaPreferencesSection
@end

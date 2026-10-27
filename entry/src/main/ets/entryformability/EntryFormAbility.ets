import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { widgetSyncManager, IslandCardFormData } from '../utils/WidgetSyncManager';

const DOMAIN = 0x0000;
const TAG = 'EntryFormAbility';

// 向后导出数据模型以兼容外部引用
export { IslandCardFormData };

/**
 * 时光岛 - 桌面元服务原子化卡片生命周期服务 (EntryFormAbility)
 * 职责:
 * 1. 响应桌面卡片添加、定时刷新、可见性感知与销毁生命周期；
 * 2. 结合现实自然时间推算岛屿晨昏微气候；
 * 3. 读取本地持久化真实心流蓄水量，驱动桌面 2x2/2x4 卡片实时同步；
 * 4. 响应系统深浅色/多语言切换全量重绘。
 */
export default class EntryFormAbility extends FormExtensionAbility {
  /**
   * 卡片创建并添加到桌面
   */
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'EntryFormAbility onAddForm called');

    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    const dimension = (want.parameters?.[formInfo.FormParam.DIMENSION_KEY] as number) || 2;

    // 1. 依据现实自然时间推断岛屿晨昏槽位与多语言标题
    const biomeInfo = widgetSyncManager.getBiomeSlotAndTitle(this.context);
    const biomeSlot = biomeInfo.slot;
    const biomeTitle = biomeInfo.title;

    let defaultTag = '';
    try {
      defaultTag = this.context.resourceManager.getStringSync($r('app.string.tag_name_code').id);
    } catch (err) {
      defaultTag = 'Flow';
    }

    // 2. 构造初始桌面卡片真实模型
    const initialFormData = new IslandCardFormData(
      0,
      0,
      defaultTag,
      biomeSlot,
      biomeTitle,
      10,
      15
    );
    initialFormData.formDimension = dimension;

    // 3. 异步注册活跃卡片 ID 及其规格，预约 30 分钟后定时刷新以跟随晨昏自然流转
    if (formId) {
      widgetSyncManager.addActiveFormId(this.context, formId, dimension).then(() => {
        // 预约下一次自然时段刷新 (30 分钟)
        formProvider.setFormNextRefreshTime(formId, 30).catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'Failed to set next refresh time: %{public}s', err.message);
        });
      }).catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, 'Failed to register active form ID: %{public}s', err.message);
      });
    }

    return formBindingData.createFormBindingData(initialFormData);
  }

  /**
   * 临时卡片转为常驻卡片
   */
  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'EntryFormAbility onCastToNormalForm: %{public}s', formId);
    widgetSyncManager.addActiveFormId(this.context, formId).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to cast form to normal: %{public}s', err.message);
    });
  }

  /**
   * 定时或系统刷新卡片数据
   */
  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'EntryFormAbility onUpdateForm: %{public}s', formId);

    // 读取本地最新专注数据与微气候并刷新
    widgetSyncManager.updateSingleForm(this.context, formId).then(() => {
      // 循环续约 30 分钟后的下一次自然时段刷新
      formProvider.setFormNextRefreshTime(formId, 30).catch(() => {});
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to update form onUpdateForm: %{public}s', err.message);
    });
  }

  /**
   * 卡片可见性改变 (当卡片滑动进入屏幕可见视窗时按需刷新)
   */
  onChangeFormVisibility(newStatus: Record<string, number>): void {
    hilog.info(DOMAIN, TAG, 'EntryFormAbility onChangeFormVisibility');

    const keys = Object.keys(newStatus);
    for (const formId of keys) {
      const visibility = newStatus[formId];
      if (visibility === formInfo.VisibilityType.FORM_VISIBLE) {
        widgetSyncManager.updateSingleForm(this.context, formId).catch(() => {});
      }
    }
  }

  /**
   * 处理卡片发起的事件交互 (例如在卡片上触发刷新或自定义交互)
   */
  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'EntryFormAbility onFormEvent: %{public}s, msg: %{public}s', formId, message);

    try {
      // 解析卡片传递的自定义事件
      widgetSyncManager.updateSingleForm(this.context, formId).catch(() => {});
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to process onFormEvent: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 卡片从桌面移除 (清理活跃 ID 防止无效刷新)
   */
  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'EntryFormAbility onRemoveForm: %{public}s', formId);
    widgetSyncManager.removeActiveFormId(this.context, formId).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to remove form ID: %{public}s', err.message);
    });
  }

  /**
   * 配置或系统语言/深浅主题变化 (全量更新所有桌面卡片文字与色调)
   */
  onConfigurationUpdate(config: Configuration): void {
    hilog.info(
      DOMAIN,
      TAG,
      'EntryFormAbility onConfigurationUpdate: language=%{public}s, colorMode=%{public}s',
      config.language ?? 'default',
      String(config.colorMode ?? -1)
    );
    widgetSyncManager.refreshAllWidgets(this.context, config).catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'Failed to refresh widgets on config update: %{public}s', err.message);
    });
  }
}

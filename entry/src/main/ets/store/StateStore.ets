import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppState, createDefaultState, encode, decode } from '../model/Engine';

const KEY: string = 'snapshot_v1';
export async function loadState(context: common.UIAbilityContext): Promise<AppState> {
  const store = await preferences.getPreferences(context, { name: 'dorm_link' });
  const raw = await store.get(KEY, '');
  if (typeof raw !== 'string') { throw new Error('存档类型无效'); }
  return raw.length === 0 ? createDefaultState() : decode(raw);
}
export async function saveState(context: common.UIAbilityContext, state: AppState): Promise<void> {
  const raw: string = encode(state);
  const store = await preferences.getPreferences(context, { name: 'dorm_link' });
  await store.put(KEY, raw);
  await store.flush();
}

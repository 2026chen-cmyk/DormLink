export interface Environment {
  temperature: number;
  light: number;
  people: number;
}
export interface Device { id: string; name: string; on: boolean; }
export interface Condition { field: string; op: string; value: number; }
export interface Rule {
  id: number;
  name: string;
  enabled: boolean;
  priority: number;
  conditions: Condition[];
  deviceId: string;
  action: boolean;
}
export interface ExecutionLog {
  sequence: number;
  time: string;
  ruleId: number;
  ruleName: string;
  input: Environment;
  status: string;
  detail: string;
}
export interface AppState {
  version: number;
  environment: Environment;
  devices: Device[];
  rules: Rule[];
  logs: ExecutionLog[];
  nextRuleId: number;
}
export function validateEnvironment(e: Environment): void {
  if (!e || !Number.isFinite(e.temperature) || e.temperature < 0 || e.temperature > 50 ||
    !Number.isFinite(e.light) || e.light < 0 || e.light > 1000 ||
    !Number.isInteger(e.people) || e.people < 0 || e.people > 8) {
    throw new Error('环境无效：温度 0～50，照度 0～1000，人数为 0～8 整数');
  }
}
export function validateRule(r: Rule): void {
  if (!r || !Number.isInteger(r.id) || r.id < 1 || typeof r.name !== 'string' ||
    r.name.trim().length < 1 || r.name.trim().length > 30 || typeof r.enabled !== 'boolean' ||
    typeof r.action !== 'boolean' || !Number.isInteger(r.priority) || r.priority < 0 || r.priority > 100 ||
    ['light', 'ac', 'curtain', 'socket'].indexOf(r.deviceId) < 0 || !Array.isArray(r.conditions) ||
    r.conditions.length < 1 || r.conditions.length > 2) { throw new Error('规则格式无效'); }
  r.conditions.forEach((c: Condition) => {
    if (!c || ['temperature', 'light', 'people'].indexOf(c.field) < 0 ||
      ['lt', 'gt', 'eq'].indexOf(c.op) < 0 || !Number.isFinite(c.value)) { throw new Error('条件格式无效'); }
    const limit: number = c.field === 'temperature' ? 50 : (c.field === 'light' ? 1000 : 8);
    if (c.value < 0 || c.value > limit || (c.field === 'people' && !Number.isInteger(c.value))) {
      throw new Error('条件阈值越界或人数非整数');
    }
  });
}
export function createDefaultState(): AppState {
  return {
    version: 1, environment: { temperature: 28, light: 150, people: 2 }, nextRuleId: 5,
    devices: [
      { id: 'light', name: '照明灯', on: false }, { id: 'ac', name: '空调', on: false },
      { id: 'curtain', name: '窗帘', on: false }, { id: 'socket', name: '插座', on: false }
    ],
    rules: [
      { id: 1, name: '有人且昏暗时开灯', enabled: true, priority: 80,
        conditions: [{ field: 'people', op: 'gt', value: 0 }, { field: 'light', op: 'lt', value: 300 }], deviceId: 'light', action: true },
      { id: 2, name: '高温开启空调', enabled: true, priority: 60,
        conditions: [{ field: 'temperature', op: 'gt', value: 26 }], deviceId: 'ac', action: true },
      { id: 3, name: '无人关闭照明', enabled: true, priority: 90,
        conditions: [{ field: 'people', op: 'eq', value: 0 }], deviceId: 'light', action: false },
      { id: 4, name: '白天打开窗帘', enabled: true, priority: 50,
        conditions: [{ field: 'light', op: 'gt', value: 500 }], deviceId: 'curtain', action: true }
    ], logs: []
  };
}
function validateState(s: AppState): void {
  if (!s || s.version !== 1) { throw new Error('存档版本不支持'); }
  validateEnvironment(s.environment);
  if (!Array.isArray(s.devices) || s.devices.length !== 4 || !Array.isArray(s.rules) ||
    s.rules.length > 30 || !Array.isArray(s.logs) || s.logs.length > 200 ||
    !Number.isInteger(s.nextRuleId) || s.nextRuleId < 1) { throw new Error('存档结构无效'); }
  const ids: string[] = [];
  s.devices.forEach((d: Device) => {
    if (!d || ['light', 'ac', 'curtain', 'socket'].indexOf(d.id) < 0 || ids.indexOf(d.id) >= 0 ||
      typeof d.name !== 'string' || typeof d.on !== 'boolean') { throw new Error('设备数据无效'); }
    ids.push(d.id);
  });
  const ruleIds: number[] = [];
  s.rules.forEach((r: Rule) => {
    validateRule(r);
    if (ruleIds.indexOf(r.id) >= 0 || r.id >= s.nextRuleId) { throw new Error('规则 id 无效'); }
    ruleIds.push(r.id);
  });
  let previous: number = 0;
  s.logs.forEach((l: ExecutionLog) => {
    if (!l || !Number.isInteger(l.sequence) || l.sequence <= previous ||
      typeof l.time !== 'string' || typeof l.ruleName !== 'string' || typeof l.detail !== 'string' ||
      !Number.isInteger(l.ruleId) || l.ruleId < 1 ||
      ['执行', '冲突跳过', '未匹配', '已停用'].indexOf(l.status) < 0) { throw new Error('执行日志无效'); }
    validateEnvironment(l.input);
    previous = l.sequence;
  });
}
export function encode(s: AppState): string { validateState(s); return JSON.stringify(s); }
export function decode(raw: string): AppState {
  const s: AppState = JSON.parse(raw) as AppState;
  validateState(s);
  return s;
}
export function copy(s: AppState): AppState { return decode(encode(s)); }
function valueOf(e: Environment, field: string): number {
  if (field === 'temperature') { return e.temperature; }
  if (field === 'light') { return e.light; }
  return e.people;
}
export function conditionText(c: Condition): string {
  const name: string = c.field === 'temperature' ? '温度' : (c.field === 'light' ? '照度' : '人数');
  return name + (c.op === 'lt' ? ' < ' : (c.op === 'gt' ? ' > ' : ' = ')) + c.value;
}
export function run(state: AppState, now: string): AppState {
  const s: AppState = copy(state);
  const ordered: Rule[] = s.rules.slice().sort((a: Rule, b: Rule) => b.priority - a.priority || a.id - b.id);
  const claimed: string[] = [];
  let sequence: number = s.logs.length > 0 ? s.logs[s.logs.length - 1].sequence : 0;
  ordered.forEach((r: Rule) => {
    const matched: boolean = r.conditions.every((c: Condition) => {
      const v: number = valueOf(s.environment, c.field);
      return c.op === 'lt' ? v < c.value : (c.op === 'gt' ? v > c.value : v === c.value);
    });
    let status: string = '未匹配';
    let detail: string = r.conditions.map((c: Condition) => conditionText(c)).join(' 且 ');
    if (!r.enabled) { status = '已停用'; }
    else if (matched) {
      if (claimed.indexOf(r.deviceId) >= 0) {
        status = '冲突跳过'; detail += '；该设备已由优先级更高或同级 id 更小的规则控制';
      } else {
        const device: Device | undefined = s.devices.find((d: Device) => d.id === r.deviceId);
        if (device === undefined) { throw new Error('目标设备不存在'); }
        status = '执行';
        detail += '；' + device.name + '：' + (device.on ? '开' : '关') + ' → ' + (r.action ? '开' : '关');
        device.on = r.action;
        claimed.push(r.deviceId);
      }
    }
    sequence++;
    s.logs.push({ sequence: sequence, time: now, ruleId: r.id, ruleName: r.name,
      input: { temperature: s.environment.temperature, light: s.environment.light, people: s.environment.people },
      status: status, detail: detail });
  });
  s.logs = s.logs.slice(-200);
  return s;
}

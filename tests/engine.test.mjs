import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
// Node 24 can strip erasable TS syntax. Copy the exact .ets source, never reimplement it.
const source = readFileSync(new URL('../entry/src/main/ets/model/Engine.ets', import.meta.url), 'utf8');
const runtime = new URL('./.runtime/', import.meta.url);
mkdirSync(runtime, { recursive: true });
writeFileSync(new URL('Engine.mts', runtime), source);
console.log('Engine.ets SHA256:', createHash('sha256').update(source).digest('hex'));
const { createDefaultState: initial, run, validateEnvironment, validateRule, encode, decode } = await import('./.runtime/Engine.mts');
const now = '2026-11-14T00:00:00Z';
const on = (s,id) => s.devices.find(d => d.id === id).on;
test('T01 正常：高温且有人昏暗，开空调与灯', () => {
  const s=run(initial(),now); assert.equal(on(s,'ac'),true); assert.equal(on(s,'light'),true);
  assert.deepEqual(s.logs.map(l=>l.ruleId),[3,1,2,4]);
});
test('T02 AND：仅昏暗但无人不触发开灯', () => {
  const s=initial(); s.environment.people=0; const r=run(s,now);
  assert.equal(on(r,'light'),false); assert.equal(r.logs.find(l=>l.ruleId===1).status,'未匹配');
});
test('T03 禁用规则不执行', () => {
  const s=initial(); s.rules[1].enabled=false; const r=run(s,now);
  assert.equal(on(r,'ac'),false); assert.equal(r.logs.find(l=>l.ruleId===2).status,'已停用');
});
function conflicting(priority=95) {
  const s=initial(); s.rules.push({id:5,name:'高温节能关空调',enabled:true,priority,
    conditions:[{field:'temperature',op:'gt',value:26}],deviceId:'ac',action:false}); s.nextRuleId=6; return s;
}
test('T04 冲突：高优先级关闭获胜并记录跳过', () => {
  const r=run(conflicting(),now); assert.equal(on(r,'ac'),false);
  assert.equal(r.logs.find(l=>l.ruleId===2).status,'冲突跳过');
});
test('T05 同级冲突：较小 id 获胜，与数组位置无关', () => {
  const s=conflicting(60); s.rules.reverse(); const r=run(s,now);
  assert.equal(on(r,'ac'),true); assert.equal(r.logs.find(l=>l.ruleId===5).status,'冲突跳过');
});
test('T06 阈值边界：温度等于 26 不满足大于', () => {
  const s=initial(); s.environment.temperature=26; assert.equal(on(run(s,now),'ac'),false);
});
test('T07 合法边界：环境上下限可执行', () => {
  validateEnvironment({temperature:0,light:0,people:0}); validateEnvironment({temperature:50,light:1000,people:8});
});
test('T08 异常输入：NaN、越界、人数非整数被拒绝', () => {
  for (const e of [{temperature:NaN,light:0,people:0},{temperature:51,light:0,people:0},
    {temperature:20,light:1001,people:0},{temperature:20,light:1,people:0.5}]) assert.throws(()=>validateEnvironment(e));
});
test('T09 非法规则：无条件、非法设备、阈值、优先级', () => {
  const base=initial().rules[0];
  for (const patch of [{conditions:[]},{deviceId:'fan'},{priority:101},
    {conditions:[{field:'people',op:'gt',value:0.5}]},{name:' '}]) assert.throws(()=>validateRule({...base,...patch}));
});
test('T10 完整快照往返恢复设备规则环境日志和序号', () => {
  const s=run(conflicting(),now); assert.deepEqual(decode(encode(s)),s);
});
test('T11 损坏/未知版本/重复设备存档拒绝', () => {
  assert.throws(()=>decode('{broken')); assert.throws(()=>decode('null')); const s=initial(); s.version=2;
  assert.throws(()=>decode(JSON.stringify(s))); s.version=1; s.devices[1]=s.devices[0]; assert.throws(()=>encode(s));
});
test('T12 引擎不修改调用方输入', () => {
  const s=initial(), before=JSON.stringify(s); run(s,now); assert.equal(JSON.stringify(s),before);
});
test('T13 200 条日志上限且序号持续递增', () => {
  let s=initial(); for(let i=0;i<60;i++) s=run(s,now);
  assert.equal(s.logs.length,200); assert.equal(s.logs[0].sequence,41); assert.equal(s.logs.at(-1).sequence,240);
});
test('T14 无规则保留设备状态，不产生伪日志', () => {
  const s=initial(); s.rules=[]; assert.deepEqual(run(s,now),s);
});
test('T15 重复规则 id 或错误 nextRuleId 拒绝恢复', () => {
  const s=initial(); s.rules[1].id=1; assert.throws(()=>encode(s));
  const t=initial(); t.nextRuleId=4; assert.throws(()=>encode(t));
});
test('T16 不匹配的高优先级规则不占用设备', () => {
  const s=conflicting(); s.rules[4].conditions[0].value=40;
  assert.equal(on(run(s,now),'ac'),true);
});
test('T17 调整优先级后冲突结果改变', () => {
  const s=conflicting(); assert.equal(on(run(s,now),'ac'),false); s.rules[1].priority=100;
  assert.equal(on(run(s,now),'ac'),true);
});
test('T18 恢复后继续运行序号衔接且保留旧日志', () => {
  const s=decode(encode(run(initial(),now))); const r=run(s,'later');
  assert.equal(r.logs.length,8); assert.equal(r.logs[4].sequence,5); assert.equal(r.logs[4].time,'later');
});

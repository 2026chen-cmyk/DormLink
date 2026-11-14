import { describe, it, expect } from '@ohos/hypium';
import { createDefaultState, run, encode, decode, validateEnvironment, Rule } from '../main/ets/model/Engine';
export default function engineTest() {
  describe('DormLinkEngine', () => {
    it('normal_temperature_trigger', 0, () => {
      const result = run(createDefaultState(), 'mock'); expect(result.devices[1].on).assertTrue();
    });
    it('and_condition_needs_people', 0, () => {
      const state = createDefaultState(); state.environment.people = 0;
      expect(run(state, 'mock').devices[0].on).assertFalse();
    });
    it('disabled_rule_skipped', 0, () => {
      const state = createDefaultState(); state.rules[1].enabled = false;
      expect(run(state, 'mock').devices[1].on).assertFalse();
    });
    it('threshold_boundary', 0, () => {
      const state = createDefaultState(); state.environment.temperature = 26;
      expect(run(state, 'mock').devices[1].on).assertFalse();
    });
    it('invalid_environment_rejected', 0, () => {
      let failed: boolean = false;
      try { validateEnvironment({ temperature: 51, light: 1, people: 0 }); } catch (e) { failed = true; }
      expect(failed).assertTrue();
    });
    it('snapshot_round_trip', 0, () => {
      const state = run(createDefaultState(), 'mock');
      expect(encode(decode(encode(state)))).assertEqual(encode(state));
    });
    it('higher_priority_wins_conflict', 0, () => {
      const state = createDefaultState();
      const rule: Rule = { id: 5, name: '关闭空调', enabled: true, priority: 100,
        conditions: [{ field: 'temperature', op: 'gt', value: 26 }], deviceId: 'ac', action: false };
      state.rules.push(rule); state.nextRuleId = 6;
      const result = run(state, 'mock'); expect(result.devices[1].on).assertFalse();
      expect(result.logs[0].ruleId).assertEqual(5);
      expect(result.logs.find((log) => log.ruleId === 2)?.status).assertEqual('冲突跳过');
    });
    it('source_state_unchanged', 0, () => {
      const state = createDefaultState(); const before: string = encode(state); run(state, 'mock');
      expect(encode(state)).assertEqual(before);
    });
  });
}

import { common } from '@kit.AbilityKit';
import { AppState, Rule, Condition, Device, ExecutionLog, createDefaultState, copy, run,
  validateRule, validateEnvironment, conditionText } from '../model/Engine';
import { loadState, saveState } from '../store/StateStore';

@Entry
@Component
struct Index {
  @State state: AppState = createDefaultState();
  @State ready: boolean = false;
  @State busy: boolean = false;
  @State readFailed: boolean = false;
  @State dirty: boolean = false;
  @State notice: string = '正在读取本地存档…';
  @State temperature: string = '28';
  @State light: string = '150';
  @State people: string = '2';
  @State editingId: number = 0;
  @State name: string = '';
  @State priority: string = '50';
  @State field1: number = 0;
  @State op1: number = 1;
  @State threshold1: string = '26';
  @State useSecond: boolean = false;
  @State field2: number = 2;
  @State op2: number = 1;
  @State threshold2: string = '0';
  @State deviceIndex: number = 1;
  @State action: boolean = true;
  @State ruleEnabled: boolean = true;
  private fields: string[] = ['temperature', 'light', 'people'];
  private ops: string[] = ['lt', 'gt', 'eq'];
  private devices: string[] = ['light', 'ac', 'curtain', 'socket'];
  private fieldLabels: string[] = ['温度', '照度', '人数'];
  private opLabels: string[] = ['<', '>', '='];
  private deviceLabels: string[] = ['灯', '空调', '窗帘', '插座'];
  private actionLabels: string[] = ['开启 / 打开', '关闭'];

  aboutToAppear(): void { this.restore(); }
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private syncEnvironment(): void {
    this.temperature = String(this.state.environment.temperature);
    this.light = String(this.state.environment.light);
    this.people = String(this.state.environment.people);
  }
  private async restore(): Promise<void> {
    this.busy = true;
    try {
      this.state = await loadState(this.context());
      this.syncEnvironment(); this.ready = true; this.notice = '已载入本地状态';
    } catch (e) {
      this.readFailed = true; this.notice = '存档读取失败，已阻止覆盖。请确认后重置存档。';
    } finally { this.busy = false; }
  }
  private async commit(next: AppState): Promise<void> {
    if (this.busy) { this.notice = '正在保存上一步操作，请稍后重试'; return; }
    if (!this.ready || this.readFailed) { return; }
    this.busy = true; this.state = next; this.dirty = true;
    try {
      await saveState(this.context(), next);
      this.dirty = false; this.notice = '已保存到本地 · ' + new Date().toLocaleTimeString();
    } catch (e) { this.notice = '保存失败，当前修改尚未落盘，请重试保存后再退出'; }
    finally { this.busy = false; }
  }
  private numberValue(text: string): number {
    if (text.trim().length === 0) { throw new Error('数值不能为空'); }
    const value: number = Number(text);
    if (!Number.isFinite(value)) { throw new Error('请输入有效数字'); }
    return value;
  }
  private execute(): void {
    try {
      const next: AppState = copy(this.state);
      next.environment = { temperature: this.numberValue(this.temperature),
        light: this.numberValue(this.light), people: this.numberValue(this.people) };
      validateEnvironment(next.environment);
      this.commit(run(next, new Date().toISOString()));
    } catch (e) { this.notice = '执行失败：检查温度 0～50、照度 0～1000、人数 0～8 整数'; }
  }
  private scene(night: boolean): void {
    const next: AppState = copy(this.state);
    next.environment = night ? { temperature: 24, light: 30, people: 0 } :
      { temperature: 30, light: 200, people: 2 };
    this.temperature = String(next.environment.temperature);
    this.light = String(next.environment.light);
    this.people = String(next.environment.people);
    this.commit(next);
  }
  private edit(r: Rule): void {
    this.editingId = r.id; this.name = r.name; this.priority = String(r.priority);
    this.field1 = this.fields.indexOf(r.conditions[0].field);
    this.op1 = this.ops.indexOf(r.conditions[0].op); this.threshold1 = String(r.conditions[0].value);
    this.useSecond = r.conditions.length === 2;
    if (this.useSecond) {
      this.field2 = this.fields.indexOf(r.conditions[1].field);
      this.op2 = this.ops.indexOf(r.conditions[1].op); this.threshold2 = String(r.conditions[1].value);
    }
    this.deviceIndex = this.devices.indexOf(r.deviceId); this.action = r.action; this.ruleEnabled = r.enabled;
  }
  private clearForm(): void {
    this.editingId = 0; this.name = ''; this.priority = '50'; this.ruleEnabled = true;
    this.field1 = 0; this.op1 = 1; this.threshold1 = '26'; this.useSecond = false;
    this.field2 = 2; this.op2 = 1; this.threshold2 = '0'; this.deviceIndex = 1; this.action = true;
  }
  private saveRule(): void {
    try {
      const conditions: Condition[] = [{ field: this.fields[this.field1], op: this.ops[this.op1], value: this.numberValue(this.threshold1) }];
      if (this.useSecond) { conditions.push({ field: this.fields[this.field2], op: this.ops[this.op2], value: this.numberValue(this.threshold2) }); }
      const r: Rule = { id: this.editingId || this.state.nextRuleId, name: this.name.trim(),
        enabled: this.ruleEnabled, priority: this.numberValue(this.priority), conditions: conditions,
        deviceId: this.devices[this.deviceIndex], action: this.action };
      validateRule(r);
      const next: AppState = copy(this.state);
      if (this.editingId === 0) {
        if (next.rules.length >= 30) { this.notice = '最多 30 条规则，请先删除不需要的规则'; return; }
        next.rules.push(r); next.nextRuleId++;
      } else { next.rules = next.rules.map((old: Rule) => old.id === r.id ? r : old); }
      this.commit(next); this.clearForm();
    } catch (e) { this.notice = '规则无效：名称 1～30 字，优先级 0～100 整数，阈值需在对应环境范围内'; }
  }
  private toggle(r: Rule): void {
    const next: AppState = copy(this.state);
    next.rules.forEach((item: Rule) => { if (item.id === r.id) { item.enabled = !item.enabled; } });
    this.commit(next);
  }
  private remove(r: Rule): void {
    const next: AppState = copy(this.state);
    next.rules = next.rules.filter((item: Rule) => item.id !== r.id);
    if (this.editingId === r.id) { this.clearForm(); }
    this.commit(next);
  }
  private reset(): void {
    AlertDialog.show({ title: '确认重置本地存档？', message: '设备、规则和执行记录将恢复初始状态。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认重置', action: () => {
        this.readFailed = false; this.ready = true; this.clearForm();
        const next: AppState = createDefaultState(); this.state = next; this.syncEnvironment(); this.commit(next);
      } } });
  }
  @Builder
  heading(title: string, hint: string) {
    Column({ space: 4 }) {
      Text(title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#132A43')
      Text(hint).fontSize(12).fontColor('#586E80')
    }.alignItems(HorizontalAlign.Start).width('100%')
  }
  @Builder
  ruleCard(r: Rule) {
    Column({ space: 8 }) {
      Row() {
        Text(r.name).fontSize(16).fontWeight(FontWeight.Bold).layoutWeight(1)
        Text(r.enabled ? '已启用' : '已停用').fontColor(r.enabled ? '#007F70' : '#727C87')
      }.width('100%')
      Text('P' + r.priority + ' · #' + r.id + ' · ' + r.conditions.map((c: Condition) => conditionText(c)).join(' 且 '))
        .fontSize(13).fontColor('#586E80').width('100%')
      Text('动作：' + r.deviceId + ' → ' + (r.action ? '开启 / 打开' : '关闭')).width('100%').fontSize(13)
      Row({ space: 8 }) {
        Button('编辑').onClick(() => this.edit(r))
        Button(r.enabled ? '停用' : '启用').onClick(() => this.toggle(r))
        Button('删除').backgroundColor('#A33838').onClick(() => this.remove(r))
      }
    }.padding(14).backgroundColor(Color.White).borderRadius(12).width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Text('DORM / LINK').fontSize(12).fontColor('#0C8375').letterSpacing(3)
          Text('宿舍智联实验室').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#132A43')
          Text('创建规则 · 模拟环境 · 看见联动').fontColor('#586E80').fontSize(14)
          Text(this.notice).fontSize(13).fontColor(this.dirty || this.readFailed ? '#B43636' : '#0C8375')
          if (this.dirty && !this.readFailed) { Button('重试保存').enabled(!this.busy).onClick(() => this.commit(copy(this.state))) }
          if (this.readFailed) { Button('确认后重置存档').onClick(() => this.reset()) }
        }.alignItems(HorizontalAlign.Start).width('100%')
        Column({ space: 16 }) {
          this.heading('01 / 模拟环境', '输入后点击执行，环境与执行结果一并保存')
          Row({ space: 8 }) { Button('学习场景').onClick(() => this.scene(false)); Button('夜间无人').onClick(() => this.scene(true)) }
          Row({ space: 8 }) {
            Column() { Text('温度 ℃'); TextInput({ text: this.temperature }).onChange((v: string) => this.temperature = v) }.layoutWeight(1)
            Column() { Text('照度 lx'); TextInput({ text: this.light }).onChange((v: string) => this.light = v) }.layoutWeight(1)
            Column() { Text('人数'); TextInput({ text: this.people }).onChange((v: string) => this.people = v) }.layoutWeight(1)
          }
          Button(this.busy ? '正在保存…' : '执行联动并保存').width('100%').backgroundColor('#087F73').onClick(() => this.execute())
          this.heading('02 / 设备状态', '开关可手动操作；下一轮匹配规则可覆盖手动状态')
          ForEach(this.state.devices, (d: Device) => {
            Row() {
              Text(d.name).layoutWeight(1)
              Button(d.on ? '已开启 · 点击关闭' : '已关闭 · 点击开启').backgroundColor(d.on ? '#087F73' : '#5B6B7D')
                .onClick(() => {
                  const next: AppState = copy(this.state);
                  next.devices.forEach((item: Device) => { if (item.id === d.id) { item.on = !item.on; } });
                  this.commit(next);
                })
            }.width('100%').padding(10).backgroundColor(Color.White).borderRadius(10)
          }, (d: Device) => d.id + ':' + d.on)
          this.heading('03 / 自动化规则', '数值越大越先执行；同级按 id 升序；同设备第一条命中获胜')
          ForEach(this.state.rules, (r: Rule) => { this.ruleCard(r) },
            (r: Rule) => r.id + ':' + r.enabled + ':' + r.priority + ':' + r.name + ':' + r.deviceId + ':' +
              r.action + ':' + r.conditions.length)
          this.heading(this.editingId ? '编辑规则 #' + this.editingId : '新增规则', '编辑表单位于列表下方；保存后即生效')
          TextInput({ text: this.name, placeholder: '规则名称（1～30 字）' }).maxLength(30).onChange((v: string) => this.name = v)
          TextInput({ text: this.priority, placeholder: '优先级（0～100）' }).onChange((v: string) => this.priority = v)
          Row({ space: 8 }) {
            Select([{ value: '温度' }, { value: '照度' }, { value: '人数' }]).selected(this.field1)
              .value(this.fieldLabels[this.field1]).onSelect((i: number) => this.field1 = i)
            Select([{ value: '<' }, { value: '>' }, { value: '=' }]).selected(this.op1)
              .value(this.opLabels[this.op1]).onSelect((i: number) => this.op1 = i)
            TextInput({ text: this.threshold1, placeholder: '阈值' }).layoutWeight(1).onChange((v: string) => this.threshold1 = v)
          }.width('100%')
          Row() { Text('同时满足第二个条件（AND）').layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.useSecond }).onChange((v: boolean) => this.useSecond = v) }
          if (this.useSecond) {
            Row({ space: 8 }) {
              Select([{ value: '温度' }, { value: '照度' }, { value: '人数' }]).selected(this.field2)
                .value(this.fieldLabels[this.field2]).onSelect((i: number) => this.field2 = i)
              Select([{ value: '<' }, { value: '>' }, { value: '=' }]).selected(this.op2)
                .value(this.opLabels[this.op2]).onSelect((i: number) => this.op2 = i)
              TextInput({ text: this.threshold2, placeholder: '阈值' }).layoutWeight(1).onChange((v: string) => this.threshold2 = v)
            }.width('100%')
          }
          Row({ space: 8 }) {
            Text('目标设备')
            Select([{ value: '灯' }, { value: '空调' }, { value: '窗帘' }, { value: '插座' }]).selected(this.deviceIndex)
              .value(this.deviceLabels[this.deviceIndex]).onSelect((i: number) => this.deviceIndex = i)
            Select([{ value: '开启 / 打开' }, { value: '关闭' }]).selected(this.action ? 0 : 1)
              .value(this.actionLabels[this.action ? 0 : 1]).onSelect((i: number) => this.action = i === 0)
          }.width('100%')
          Row() { Text('规则启用').layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.ruleEnabled }).onChange((v: boolean) => this.ruleEnabled = v) }
          Row({ space: 8 }) { Button('保存规则').backgroundColor('#087F73').onClick(() => this.saveRule()); Button('清空表单 / 取消编辑').onClick(() => this.clearForm()) }
          this.heading('04 / 执行记录', '最近 200 条；按执行序号逆序显示，包含未匹配、停用与冲突')
          if (this.state.logs.length === 0) { Text('暂无记录，执行一次联动开始检验规则。').fontColor('#586E80') }
          ForEach(this.state.logs.slice().reverse(), (log: ExecutionLog) => {
            Column({ space: 6 }) {
              Text('#' + log.sequence + ' · ' + log.status + ' · ' + log.ruleName).fontWeight(FontWeight.Bold).fontSize(14)
              Text(log.detail).fontSize(12)
              Text(log.time + ' · 温度 ' + log.input.temperature + ' / 照度 ' + log.input.light + ' / 人数 ' + log.input.people).fontSize(11).fontColor('#586E80')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(Color.White).borderRadius(10)
          }, (log: ExecutionLog) => String(log.sequence))
          Button('重置所有数据').backgroundColor('#A33838').onClick(() => this.reset())
        }.enabled(this.ready && !this.busy && !this.readFailed).width('100%')
        Text('离线 Mock 模拟 · 陈俊宇 · 20230313203').fontSize(12).fontColor('#586E80')
      }.padding(20).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').backgroundColor('#EEF3F8')
  }
}

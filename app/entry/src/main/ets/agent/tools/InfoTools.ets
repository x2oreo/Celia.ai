// explain_condition, get_vitals_summary — grounding facts for the model.

import { AgentTool, TurnState, toolError } from '../ToolTypes';
import { argString } from '../ResponseValidator';
import { CONDITION_TOPICS, conditionFacts } from '../ConditionFacts';
import { VitalsDigest } from '../VitalsDigest';
import { CoachTip, tipsFor } from '../../coach/Coach';

interface FactsOutput {
  topic: string;
  facts: string;
  triggerTips: string[];   // static genotype coach (coach/Coach.ets), sourced — the model may quote, not invent
}

export class ExplainConditionTool implements AgentTool {
  name: string = 'explain_condition';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const topic: string = argString(args, 'topic', 32);
    if (!CONDITION_TOPICS.includes(topic)) {
      return toolError(`topic must be one of ${CONDITION_TOPICS.join(', ')}`);
    }
    const out: FactsOutput = {
      topic: topic,
      facts: conditionFacts(topic, turn.genotype),
      triggerTips: tipsFor(turn.genotype).slice(0, 3).map((t: CoachTip) => `${t.title}: ${t.body}`)
    };
    return JSON.stringify(out);
  }
}

interface VitalsOutput {
  summary: string;
  note: string;
}

export class GetVitalsSummaryTool implements AgentTool {
  name: string = 'get_vitals_summary';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const out: VitalsOutput = {
      summary: VitalsDigest.get().summary(Date.now()),
      note: 'Wrist heart rate only — not an ECG. Do not interpret it medically.'
    };
    return JSON.stringify(out);
  }
}

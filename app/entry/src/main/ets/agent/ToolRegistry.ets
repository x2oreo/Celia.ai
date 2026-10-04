// One registry for every entry point (text loop, realtime voice, intents). Names must match
// backend/supabase/functions/_shared/tools.ts - a mismatch is caught by ToolRegistry tests.

import { AgentTool, TurnState, toolError } from './ToolTypes';
import { parseArgs } from './ResponseValidator';
import { CheckDrugTool, GetMyMedsTool, SuggestAlternativesTool } from './tools/DrugTools';
import { ExplainConditionTool, GetVitalsSummaryTool } from './tools/InfoTools';
import {
  AddMedTool, LogDoseTool, ScanMedicineTool, ShareEmergencyCardTool, ShowEmergencyCardTool, StartEmergencyTool, StartNewChatTool
} from './tools/ActionTools';
import { LogSymptomTool } from './tools/SymptomTools';
import {
  GetDoseStatusTool, GetTrendsTool, OpenRemindersTool, OpenSymptomLogTool, PrepareDoctorVisitTool
} from './tools/CareTools';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('ToolRegistry');

export class ToolRegistry {
  private tools: Map<string, AgentTool> = new Map<string, AgentTool>();

  constructor() {
    const all: AgentTool[] = [
      new CheckDrugTool(), new GetMyMedsTool(), new SuggestAlternativesTool(),
      new ExplainConditionTool(), new GetVitalsSummaryTool(),
      new ScanMedicineTool(), new AddMedTool(), new ShowEmergencyCardTool(), new StartEmergencyTool(),
      new ShareEmergencyCardTool(), new StartNewChatTool(), new LogSymptomTool(),
      new PrepareDoctorVisitTool(), new GetDoseStatusTool(), new GetTrendsTool(),
      new OpenSymptomLogTool(), new OpenRemindersTool(), new LogDoseTool()
    ];
    for (const t of all) {
      this.tools.set(t.name, t);
    }
  }

  names(): string[] {
    return Array.from(this.tools.keys());
  }

  // Never throws: unknown tools, bad arguments and executor errors become an error result for the model.
  async run(name: string, argsJson: string, turn: TurnState): Promise<string> {
    const tool: AgentTool | undefined = this.tools.get(name);
    if (tool === undefined) {
      log.warn(`unknown tool ${name}`);
      return toolError(`unknown tool ${name}`);
    }
    const args: Record<string, Object> | undefined = parseArgs(argsJson);
    if (args === undefined) {
      log.warn(`bad arguments for ${name}`);
      return toolError('arguments must be a JSON object');
    }
    turn.toolsUsed.push(name);
    try {
      return await tool.execute(args, turn);
    } catch (e) {
      log.error(`${name} failed: ${String(e)}`);
      return toolError(`${name} failed on the device`);
    }
  }
}

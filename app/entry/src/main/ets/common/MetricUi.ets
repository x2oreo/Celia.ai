// Words for the health metrics and their status (DESIGN.md §6.10). The level itself comes from vitals/Metrics.ets.

import { Direction, MetricKind, StatusLevel, StatusReason } from '../vitals/Metrics';

export class MetricUi {
  static label(kind: MetricKind): Resource {
    switch (kind) {
      case 'HEART_RATE':
        return $r('app.string.metric_heart_rate');
      case 'HRV':
        return $r('app.string.metric_hrv');
      case 'SPO2':
        return $r('app.string.metric_spo2');
      case 'BREATHING':
        return $r('app.string.metric_breathing');
      case 'SLEEP':
        return $r('app.string.metric_sleep');
      case 'STEPS':
        return $r('app.string.metric_steps');
      case 'STRESS':
        return $r('app.string.metric_stress');
      default:
        return $r('app.string.metric_resting_hr');
    }
  }

  // The short name for a card's caps label.
  static short(kind: MetricKind): Resource {
    switch (kind) {
      case 'HRV':
        return $r('app.string.metric_hrv_short');
      case 'SPO2':
        return $r('app.string.metric_spo2_short');
      case 'BREATHING':
        return $r('app.string.metric_breathing_short');
      case 'STRESS':
        return $r('app.string.metric_stress_short');
      default:
        return MetricUi.label(kind);
    }
  }

  static about(kind: MetricKind): Resource {
    switch (kind) {
      case 'HEART_RATE':
        return $r('app.string.metric_about_heart_rate');
      case 'HRV':
        return $r('app.string.metric_about_hrv');
      case 'SPO2':
        return $r('app.string.metric_about_spo2');
      case 'BREATHING':
        return $r('app.string.metric_about_breathing');
      case 'SLEEP':
        return $r('app.string.metric_about_sleep');
      case 'STEPS':
        return $r('app.string.metric_about_steps');
      case 'STRESS':
        return $r('app.string.metric_about_stress');
      default:
        return $r('app.string.metric_about_resting_hr');
    }
  }

  static level(level: StatusLevel): Resource {
    switch (level) {
      case 'GOOD':
        return $r('app.string.status_good');
      case 'OKAY':
        return $r('app.string.status_okay');
      case 'ATTENTION':
        return $r('app.string.status_attention');
      default:
        return $r('app.string.status_none');
    }
  }

  static reason(reason: StatusReason): Resource {
    switch (reason) {
      case 'IN_RANGE':
        return $r('app.string.status_in_range');
      case 'SLIGHTLY_HIGH':
        return $r('app.string.status_slightly_high');
      case 'SLIGHTLY_LOW':
        return $r('app.string.status_slightly_low');
      case 'HIGH':
        return $r('app.string.status_high');
      case 'LOW':
        return $r('app.string.status_low');
      default:
        return $r('app.string.status_no_data');
    }
  }

  // "Up 3 bpm from the week before." `amount` is the change with its unit.
  static change(direction: Direction, amount: string): Resource {
    switch (direction) {
      case 'UP':
        return $r('app.string.metric_up', amount);
      case 'DOWN':
        return $r('app.string.metric_down', amount);
      case 'STEADY':
        return $r('app.string.metric_steady');
      default:
        return $r('app.string.metric_no_change');
    }
  }

  static tint(level: StatusLevel): Resource {
    if (level === 'GOOD') {
      return $r('app.color.risk_not_listed_tint');
    }
    return level === 'ATTENTION' ? $r('app.color.risk_possible_tint') : $r('app.color.surface_alt');
  }

  static text(level: StatusLevel): Resource {
    switch (level) {
      case 'GOOD':
        return $r('app.color.risk_not_listed_text');
      case 'ATTENTION':
        return $r('app.color.risk_possible_text');
      case 'OKAY':
        return $r('app.color.ink_2');
      default:
        return $r('app.color.ink_3');
    }
  }

  static arrow(direction: Direction): string {
    if (direction === 'UP') {
      return '↑';
    }
    return direction === 'DOWN' ? '↓' : '→';
  }
}

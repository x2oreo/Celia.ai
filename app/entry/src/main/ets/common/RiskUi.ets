// Risk level → colour, icon and label. Risk is always shown as colour + icon + text, never colour alone.

import { RiskLevel } from '../model/DrugVerdict';

export class RiskUi {
  static color(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.color.risk_known');
      case 'POSSIBLE_RISK':
        return $r('app.color.risk_possible');
      case 'CONDITIONAL_RISK':
        return $r('app.color.risk_conditional');
      case 'NOT_LISTED':
        return $r('app.color.risk_not_listed');
      default:
        return $r('app.color.risk_unknown');
    }
  }

  static soft(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.color.risk_known_soft');
      case 'POSSIBLE_RISK':
        return $r('app.color.risk_possible_soft');
      case 'CONDITIONAL_RISK':
        return $r('app.color.risk_conditional_soft');
      case 'NOT_LISTED':
        return $r('app.color.risk_not_listed_soft');
      default:
        return $r('app.color.risk_unknown_soft');
    }
  }

  static icon(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.media.ic_risk_known');
      case 'POSSIBLE_RISK':
        return $r('app.media.ic_risk_possible');
      case 'CONDITIONAL_RISK':
        return $r('app.media.ic_risk_conditional');
      case 'NOT_LISTED':
        return $r('app.media.ic_risk_ok');
      default:
        return $r('app.media.ic_risk_unknown');
    }
  }

  static label(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.string.risk_known');
      case 'POSSIBLE_RISK':
        return $r('app.string.risk_possible');
      case 'CONDITIONAL_RISK':
        return $r('app.string.risk_conditional');
      case 'NOT_LISTED':
        return $r('app.string.risk_not_listed');
      default:
        return $r('app.string.risk_unknown');
    }
  }

  // Plain-English label for text that leaves the app (copied doctor questions, emergency SMS).
  static plain(risk: RiskLevel): string {
    switch (risk) {
      case 'KNOWN_RISK':
        return 'known risk of torsades';
      case 'POSSIBLE_RISK':
        return 'possible QT risk';
      case 'CONDITIONAL_RISK':
        return 'conditional QT risk';
      case 'NOT_LISTED':
        return 'not on the QT lists';
      default:
        return 'not recognised';
    }
  }
}

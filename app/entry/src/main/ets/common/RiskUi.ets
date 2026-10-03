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

  // Badge and header-band background (DESIGN.md 3).
  static tint(risk: RiskLevel): Resource {
    return RiskUi.soft(risk);
  }

  // Word colour on the tint background.
  static text(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.color.risk_known_text');
      case 'POSSIBLE_RISK':
        return $r('app.color.risk_possible_text');
      case 'CONDITIONAL_RISK':
        return $r('app.color.risk_conditional_text');
      case 'NOT_LISTED':
        return $r('app.color.risk_not_listed_text');
      default:
        return $r('app.color.risk_unknown_text');
    }
  }

  // Verdict-card outline.
  static border(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.color.risk_known_border');
      case 'POSSIBLE_RISK':
        return $r('app.color.risk_possible_border');
      case 'CONDITIONAL_RISK':
        return $r('app.color.risk_conditional_border');
      case 'NOT_LISTED':
        return $r('app.color.risk_not_listed_border');
      default:
        return $r('app.color.risk_unknown_border');
    }
  }

  // One-line subtitle under the verdict word.
  static subtitle(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.string.risk_sub_known');
      case 'POSSIBLE_RISK':
        return $r('app.string.risk_sub_possible');
      case 'CONDITIONAL_RISK':
        return $r('app.string.risk_sub_conditional');
      case 'NOT_LISTED':
        return $r('app.string.risk_sub_not_listed');
      default:
        return $r('app.string.risk_sub_unknown');
    }
  }

  static soft(risk: RiskLevel): Resource {
    switch (risk) {
      case 'KNOWN_RISK':
        return $r('app.color.risk_known_tint');
      case 'POSSIBLE_RISK':
        return $r('app.color.risk_possible_tint');
      case 'CONDITIONAL_RISK':
        return $r('app.color.risk_conditional_tint');
      case 'NOT_LISTED':
        return $r('app.color.risk_not_listed_tint');
      default:
        return $r('app.color.risk_unknown_tint');
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

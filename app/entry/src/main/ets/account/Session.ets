// The signed-in user (Workstream B1). This API is a contract with Workstream A: keep these signatures stable.
// Stub until the accounts stream lands: always signed out, so every caller already handles that case.

import { Listeners } from '../common/Listeners';

export class Session {
  private static changes: Listeners<boolean> = new Listeners<boolean>();

  static isSignedIn(): boolean {
    return false;
  }

  static userId(): string {
    return '';
  }

  // Name from the local profile, or '' when unknown.
  static userName(): string {
    return '';
  }

  static email(): string {
    return '';
  }

  // Current access token (JWT), or '' when signed out. May be expired while offline.
  static accessToken(): string {
    return '';
  }

  static async signOut(): Promise<void> {
    Session.changes.emit(false);
  }

  // Called with the new signed-in state after sign-in, sign-out or a failed refresh.
  static onChange(listener: (signedIn: boolean) => void): () => void {
    return Session.changes.add(listener);
  }
}

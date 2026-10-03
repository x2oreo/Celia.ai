// Shared contract — see docs/ARCHITECTURE.md.

export interface Medication {
  id: number;
  name: string;
  ingredient: string;
  dose: string;
  addedAt: number;
}

import { describe, it, expect } from '@ohos/hypium';
import { Profile } from '../main/ets/model/Profile';
import {
  canContinue,
  copyProfile,
  finalProfile,
  isLastStep,
  isoDate,
  isOptional,
  newProfile,
  nextStep,
  OnbStep,
  parseIsoDate,
  prevStep,
  shouldFinishAfterSignIn,
  STEP_COUNT,
  validPhone,
  withContact,
  withDetails,
  withoutContact
} from '../main/ets/onboarding/OnboardingFlow';

export default function onboardingTest() {
  describe('OnboardingFlow', () => {
    it('hasEightStepsWithClampedNavigation', 0, () => {
      expect(STEP_COUNT).assertEqual(8);
      expect(nextStep(OnbStep.WELCOME)).assertEqual(OnbStep.ACCOUNT);
      expect(nextStep(OnbStep.WATCH)).assertEqual(OnbStep.WATCH);
      expect(prevStep(OnbStep.WELCOME)).assertEqual(OnbStep.WELCOME);
      expect(prevStep(OnbStep.PERMISSIONS)).assertEqual(OnbStep.DETAILS);
      expect(isLastStep(OnbStep.WATCH)).assertTrue();
      expect(isLastStep(OnbStep.PERMISSIONS)).assertFalse();
    });

    it('onlyConsentAndAboutYouAreRequired', 0, () => {
      expect(isOptional(OnbStep.WELCOME)).assertFalse();
      expect(isOptional(OnbStep.ABOUT)).assertFalse();
      expect(isOptional(OnbStep.ACCOUNT)).assertTrue();
      expect(isOptional(OnbStep.MEDS)).assertTrue();
      expect(isOptional(OnbStep.CONTACTS)).assertTrue();
      expect(isOptional(OnbStep.DETAILS)).assertTrue();
      expect(isOptional(OnbStep.PERMISSIONS)).assertTrue();
      expect(isOptional(OnbStep.WATCH)).assertTrue();
    });

    it('welcomeNeedsConsent', 0, () => {
      const p: Profile = newProfile('PL');
      expect(canContinue(OnbStep.WELCOME, false, p)).assertFalse();
      expect(canContinue(OnbStep.WELCOME, true, p)).assertTrue();
      expect(canContinue(OnbStep.MEDS, false, p)).assertTrue();
    });

    it('aboutYouRejectsABadBirthDate', 0, () => {
      const p: Profile = newProfile('PL');
      expect(canContinue(OnbStep.ABOUT, true, p)).assertTrue();
      p.dateOfBirth = '1994-05-17';
      expect(canContinue(OnbStep.ABOUT, true, p)).assertTrue();
      p.dateOfBirth = '1994-02-30';
      expect(canContinue(OnbStep.ABOUT, true, p)).assertFalse();
      p.dateOfBirth = '3000-01-01';
      expect(canContinue(OnbStep.ABOUT, true, p)).assertFalse();
    });

    it('isoDateRoundTrips', 0, () => {
      expect(isoDate(new Date(1994, 4, 7))).assertEqual('1994-05-07');
      const d: Date | undefined = parseIsoDate('1994-05-07');
      expect(d !== undefined && isoDate(d) === '1994-05-07').assertTrue();
      expect(parseIsoDate('07.05.1994') === undefined).assertTrue();
    });

    it('newProfileHasSafeDefaults', 0, () => {
      const p: Profile = newProfile('DE');
      expect(p.condition).assertEqual('LQTS');
      expect(p.genotype).assertEqual('UNKNOWN');
      expect(p.hasIcd).assertFalse();
      expect(p.contacts.length).assertEqual(0);
      expect(p.country).assertEqual('DE');
    });

    it('copyDoesNotShareLists', 0, () => {
      const a: Profile = withContact(newProfile('PL'), 'Mum', '+48 600 100 200', 'Mother');
      a.allergies = ['penicillin'];
      const b: Profile = copyProfile(a);
      b.contacts.pop();
      b.allergies?.push('latex');
      expect(a.contacts.length).assertEqual(1);
      expect(a.allergies.length).assertEqual(1);
    });

    it('contactsAreValidatedAddedAndRemoved', 0, () => {
      expect(validPhone('600 100')).assertTrue();
      expect(validPhone('12-34')).assertFalse();
      const base: Profile = newProfile('PL');
      expect(withContact(base, ' ', '600100200', '').contacts.length).assertEqual(0);
      expect(withContact(base, 'Ola', '12', '').contacts.length).assertEqual(0);
      const one: Profile = withContact(base, '  Ola ', ' 600100200 ', ' sister ');
      expect(one.contacts[0].name).assertEqual('Ola');
      expect(one.contacts[0].relation).assertEqual('sister');
      expect(base.contacts.length).assertEqual(0);
      const two: Profile = withContact(one, 'Jan', '600100201', '');
      expect(withoutContact(two, 0).contacts[0].name).assertEqual('Jan');
    });

    it('detailsFormCannotOverwriteOtherSteps', 0, () => {
      const draft: Profile = withContact(newProfile('PL'), 'Ola', '600100200', '');
      draft.genotype = 'LQT2';
      const fromForm: Profile = newProfile('US');
      fromForm.bloodType = 'A+';
      fromForm.allergies = ['penicillin'];
      fromForm.hospital = 'Szpital';
      const merged: Profile = withDetails(draft, fromForm);
      expect(merged.bloodType).assertEqual('A+');
      expect(merged.hospital).assertEqual('Szpital');
      expect(merged.genotype).assertEqual('LQT2');
      expect(merged.country).assertEqual('PL');
      expect(merged.contacts.length).assertEqual(1);
    });

    it('finalProfileTrimsAndDropsStaleIcdModel', 0, () => {
      const p: Profile = newProfile('PL');
      p.name = '  Ola  ';
      p.notes = ' beta-blocker: nadolol ';
      p.icdModel = 'Model X';
      p.hasIcd = false;
      p.dateOfBirth = '1994-02-30';
      p.cardLanguage = '';
      const f: Profile = finalProfile(p);
      expect(f.name).assertEqual('Ola');
      expect(f.notes).assertEqual('beta-blocker: nadolol');
      expect(f.icdModel === undefined).assertTrue();
      expect(f.dateOfBirth === undefined).assertTrue();
      expect(f.cardLanguage).assertEqual('en');
      p.hasIcd = true;
      expect(finalProfile(p).icdModel).assertEqual('Model X');
      p.name = '   ';
      expect(finalProfile(p).name === undefined).assertTrue();
    });

    it('returningUserSkipsOnlyWithARestoredProfile', 0, () => {
      expect(shouldFinishAfterSignIn(true, newProfile('PL'))).assertTrue();
      expect(shouldFinishAfterSignIn(true, undefined)).assertFalse();
      expect(shouldFinishAfterSignIn(false, newProfile('PL'))).assertFalse();
    });
  });
}

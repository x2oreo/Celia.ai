import contractSmokeTest from './ContractSmoke.test';
import drugCheckerTest from './DrugChecker.test';
import alarmRulesTest from './AlarmRules.test';
import sosControllerTest from './SosController.test';
import doctorPrepTest from './DoctorPrep.test';
import utilsTest from './Utils.test';
import boxCatalogTest from './BoxCatalog.test';
import cardLinkTest from './CardLink.test';

export default function testsuite() {
  contractSmokeTest();
  drugCheckerTest();
  alarmRulesTest();
  sosControllerTest();
  doctorPrepTest();
  utilsTest();
  boxCatalogTest();
  cardLinkTest();
}

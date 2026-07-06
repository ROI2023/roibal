const kAppVersion = '1.0.0';

// Seteado en tiempo de build vía --dart-define=BUILD_TIME=...
// En desarrollo muestra 'dev'. En Netlify muestra la fecha/hora del deploy.
const kBuildTime = String.fromEnvironment('BUILD_TIME', defaultValue: 'dev');

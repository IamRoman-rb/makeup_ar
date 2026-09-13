// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'App Maquiagem AR';

  @override
  String get discoverLooks => 'Descobrir Looks';

  @override
  String get searchHint => 'Pesquisar filtros ou marcas...';

  @override
  String get categoryAll => 'Tudo';

  @override
  String get categoryLips => 'Lábios';

  @override
  String get categoryEyes => 'Olhos';

  @override
  String get categoryComplexion => 'Pele';

  @override
  String noLooksFound(Object category) {
    return 'Nenhum look encontrado na categoria $category.';
  }

  @override
  String noResultsFor(Object category, Object query) {
    return 'Nenhum resultado para \"$query\" em $category.';
  }

  @override
  String get welcomeBack => 'Bem-vindo de volta';

  @override
  String get loginSubtitle => 'Insira seus dados para entrar.';

  @override
  String get emailOrUser => 'E-mail ou Usuário';

  @override
  String get password => 'Senha';

  @override
  String get forgotPassword => 'Esqueceu sua senha?';

  @override
  String get logIn => 'ENTRAR';

  @override
  String get noAccount => 'Não tem uma conta? ';

  @override
  String get signUp => 'Cadastre-se';

  @override
  String get createProfile => 'Crie seu Perfil';

  @override
  String get joinSubtitle =>
      'Junte-se à Lumière Beauty para uma experiência cosmética única.';

  @override
  String get fullName => 'Nome Completo';

  @override
  String get email => 'E-mail';

  @override
  String get age => 'Idade';

  @override
  String get dob => 'Data de Nascimento';

  @override
  String get skinType => 'Tipo de Pele';

  @override
  String get skinTone => 'Tom de Pele';

  @override
  String get personalTastes => 'Gostos Pessoais';

  @override
  String get createAccount => 'Criar Conta';

  @override
  String get editProfile => 'Editar Perfil';

  @override
  String get updateProfile => 'Atualizar Perfil';

  @override
  String get skinTypeLabel => 'TIPO DE PELE';

  @override
  String get toneLabel => 'TOM';

  @override
  String get savedLooks => 'Looks\nSalvos';

  @override
  String get tutorials => 'Tutoriais';

  @override
  String get favorites => 'Favoritos';

  @override
  String get mySavedLooks => 'Meus Looks Salvos';

  @override
  String get viewAll => 'Ver Todos >';

  @override
  String get settings => 'Configurações';

  @override
  String get accountSettings => 'Configurações da Conta';

  @override
  String get appLanguage => 'Idioma do App';

  @override
  String get logOut => 'Sair';

  @override
  String get security => 'Segurança';

  @override
  String get changePassword => 'Mudar Senha';

  @override
  String get changePasswordDesc =>
      'Enviaremos um link de redefinição para o seu e-mail.';

  @override
  String get sendLink => 'Enviar Link';

  @override
  String get notifications => 'Notificações';

  @override
  String get pushNotif => 'Notificações Push';

  @override
  String get pushNotifDesc => 'Alertas sobre novos looks e recursos.';

  @override
  String get emailNotif => 'Boletim por E-mail';

  @override
  String get emailNotifDesc => 'Dicas de beleza semanais e inspiração.';

  @override
  String get dangerZone => 'Zona de Perigo';

  @override
  String get deleteAccount => 'Excluir Conta';

  @override
  String get deleteAccountDesc =>
      'Depois de excluir sua conta, não há como voltar. Tenha certeza.';

  @override
  String get deleteMyAccountBtn => 'Excluir Minha Conta';

  @override
  String get selectLanguageTitle => 'Idioma / Language';

  @override
  String get selectLanguageDesc =>
      'Selecione seu idioma preferido para o aplicativo.';

  @override
  String get saved => 'Salvo';

  @override
  String get save => 'Salvar';

  @override
  String get tutorial => 'Tutorial';

  @override
  String get effectOn => 'Efeito Ativ.';

  @override
  String get effectOff => 'Efeito Desat.';

  @override
  String get profileUpdated => 'Perfil atualizado com sucesso!';

  @override
  String get errorSaving => 'Erro ao salvar:';

  @override
  String get loginFirst => 'Por favor, faça login primeiro.';

  @override
  String get noSavedLooks =>
      'Você ainda não salvou nenhum look.\nExplore o catálogo para encontrar seus favoritos!';

  @override
  String get unknownLook => 'Look desconhecido';

  @override
  String get explore => 'Explorar';

  @override
  String get profile => 'Perfil';

  @override
  String get fillRequiredFields =>
      'Por favor, preencha todos os campos obrigatórios';

  @override
  String get registrationError => 'Erro de registro';

  @override
  String get stepByStepTitle => 'Guia Passo a Passo';

  @override
  String get stepLabel => 'PASSO';

  @override
  String get backBtn => 'Voltar';

  @override
  String get finishBtn => 'Terminar';

  @override
  String get nextStepBtn => 'Próximo';

  @override
  String get tutStep1Title => 'Luminous Foundation';

  @override
  String get tutStep1Desc =>
      'Aplique algumas gotas da base no centro do rosto. Esfume para fora usando um pincel ou esponja úmida para um acabamento natural, radiante e uniforme.';

  @override
  String get tutStep2Title => 'Velvet Liquid Blush';

  @override
  String get tutStep2Desc =>
      'Coloque três pequenos pontos de blush líquido nas maçãs do rosto. Esfume rapidamente com leves batidinhas em direção às têmporas para um efeito lifting espetacular.';

  @override
  String get tutStep3Title => 'Gold Highlighter';

  @override
  String get tutStep3Desc =>
      'Aplique suavemente o iluminador nos pontos altos do rosto: parte superior das maçãs do rosto, ponte do nariz e arco do cupido para um brilho deslumbrante.';
}

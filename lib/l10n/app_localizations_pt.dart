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
  String get mirror => 'Espelho';

  @override
  String get testFilter => 'Filtro de teste';

  @override
  String get testFilterNone => 'Sem filtro';

  @override
  String get testFilterIntensity => 'Intensidade';

  @override
  String get testFilterNote =>
      'Motor novo (beta): cada look é aplicado por completo com rastreamento facial. Na primeira vez leva alguns segundos para carregar.';

  @override
  String get testFilterShowPoints => 'Ver pontos';

  @override
  String get testFilterZoneAll => 'Tudo';

  @override
  String get testFilterZoneLips => 'Lábios';

  @override
  String get testFilterZoneEyes => 'Olhos';

  @override
  String get testFilterZoneCheeks => 'Bochechas';

  @override
  String get testFilterZoneSkin => 'Pele';

  @override
  String get testFilterUnavailable =>
      'A maquiagem ao vivo não está disponível neste aparelho. Mostrando o espelho normal.';

  @override
  String get testFilterCompare => 'Segure para comparar';

  @override
  String get testFilterFinishMatte => 'Matte';

  @override
  String get testFilterFinishSatin => 'Acetinado';

  @override
  String get testFilterFinishGloss => 'Brilho';

  @override
  String get testFilterFinishShimmer => 'Cintilante';

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

  @override
  String get tryOnAr => 'Experimentar em RA';

  @override
  String get studioTitle => 'Studio IA';

  @override
  String get studioMenuStudio => 'Criar com IA (Studio)';

  @override
  String get studioMenuSteps => 'Editar passos do tutorial';

  @override
  String get studioPromptHint =>
      'Descreva o look (ex.: lábios góticos e blush laranja)';

  @override
  String get studioGenerate => 'Gerar';

  @override
  String get studioRemixHint => 'Ajuste (ex.: mais natural, tons mais quentes)';

  @override
  String get studioRemix => 'Remix';

  @override
  String get studioNote =>
      'Studio: escolha uma variante e ajuste antes de publicar.';

  @override
  String get studioEmpty => 'Escreva um pedido e toque em Gerar.';

  @override
  String get studioSaveDraft => 'Salvar rascunho';

  @override
  String get studioPublish => 'Publicar';

  @override
  String get studioDrafts => 'Rascunhos';

  @override
  String get studioNoDrafts => 'Não há rascunhos.';

  @override
  String get studioDeleteDraft => 'Excluir rascunho';

  @override
  String get studioSaved => 'Rascunho salvo.';

  @override
  String get studioPublished => 'Look publicado no catálogo.';

  @override
  String get studioSaveError => 'Não foi possível salvar. Verifique a conexão.';

  @override
  String get studioName => 'Nome';

  @override
  String get studioCategory => 'Categoria';

  @override
  String get studioImageUrl => 'URL da imagem (opcional)';

  @override
  String get studioCancel => 'Cancelar';

  @override
  String get studioAccept => 'OK';

  @override
  String get studioRemove => 'Remover';

  @override
  String get studioColorHex => 'Cor (#RRGGBB)';

  @override
  String get studioFinish => 'Acabamento';

  @override
  String get studioLayerLips => 'Batom';

  @override
  String get studioLayerLipLiner => 'Contorno labial';

  @override
  String get studioLayerCheeks => 'Blush';

  @override
  String get studioLayerFoundation => 'Base';

  @override
  String get studioLayerContour => 'Contorno';

  @override
  String get studioLayerHighlight => 'Iluminador';

  @override
  String get studioLayerEyeLiner => 'Delineador';

  @override
  String get studioLayerLashes => 'Cílios';

  @override
  String studioLayerShadow(int index) {
    return 'Sombra $index';
  }

  @override
  String get studioFallback =>
      'A IA não retornou variantes válidas: mostrando o preset mais parecido.';

  @override
  String get studioErrorAuth => 'Faça login para usar o Studio.';

  @override
  String get studioErrorAdmin => 'Somente administradores podem gerar looks.';

  @override
  String get studioErrorInput => 'O pedido deve ter entre 1 e 300 caracteres.';

  @override
  String get studioErrorQuota => 'A cota de hoje acabou. Tente amanhã.';

  @override
  String get studioErrorUnavailable =>
      'O gerador não responde. Tente novamente mais tarde.';

  @override
  String get studioErrorAppCheck =>
      'O app não passou na verificação (App Check).';

  @override
  String get studioErrorUnknown => 'Não foi possível gerar.';

  @override
  String get studioFromPhoto => 'Da foto';

  @override
  String get studioPalette => 'Paleta de produto';

  @override
  String get studioPhotoNoticeTitle => 'Foto de referência';

  @override
  String get studioPhotoNotice =>
      'A foto é analisada neste telefone: não é enviada nem salva. Use fotos próprias ou com permissão da pessoa que aparece.';

  @override
  String get studioContinue => 'Continuar';

  @override
  String get studioPhotoNoFace => 'Nenhum rosto foi encontrado na foto.';

  @override
  String get studioPhotoSmall =>
      'O rosto está muito pequeno: use uma foto mais próxima.';

  @override
  String get studioPhotoProfile =>
      'O rosto está virado: use uma foto de frente.';

  @override
  String get studioPhotoBad => 'Não foi possível analisar a foto.';

  @override
  String get studioPhotoFaithful => 'Foto · fiel';

  @override
  String get studioPhotoBolder => 'Foto · intensa';

  @override
  String get studioPhotoSubtler => 'Foto · sutil';

  @override
  String get studioPhotoRough =>
      'Ajuste aproximado: confira as cores na pré-visualização.';

  @override
  String studioRegionConfidence(String layer, int percent) {
    return '$layer: $percent%';
  }

  @override
  String get studioPaletteEmpty => 'Nenhuma cor foi encontrada na foto.';

  @override
  String get studioPalettePickLayer => 'Onde vai esta cor?';

  @override
  String get studioNewShadow => 'Nova sombra';

  @override
  String get studioQaTitle => 'Controle de qualidade';

  @override
  String get studioQaVisibility => 'Visibilidade';

  @override
  String get studioQaClipping => 'Saturação';

  @override
  String get studioQaConsistency => 'Tons de pele';

  @override
  String get studioQaCoverage => 'Cobertura';

  @override
  String get studioQaCost => 'Desempenho';

  @override
  String get studioQaOk => 'Ok';

  @override
  String get studioQaCostOk => 'Dentro do medido no telefone de referência';

  @override
  String studioQaInvisible(String layer) {
    return '$layer: não aparece em nenhum tom de pele';
  }

  @override
  String studioQaSubtle(String layer) {
    return '$layer: quase não aparece';
  }

  @override
  String studioQaWashedOut(String layer) {
    return '$layer: cor muito saturada, desbota com a luz';
  }

  @override
  String studioQaChalky(String layer) {
    return '$layer: fica esbranquiçado em pele escura';
  }

  @override
  String studioQaAshy(String layer) {
    return '$layer: fica acinzentado em pele escura';
  }

  @override
  String studioQaFades(String layer) {
    return '$layer: não aparece em alguns tons';
  }

  @override
  String get studioQaExtremeLiner => 'Delineado e asa no máximo';

  @override
  String get studioQaMaskFoundation => 'Base muito pesada (efeito máscara)';

  @override
  String get studioQaHeavyBlush => 'Blush muito grande e intenso';

  @override
  String get studioQaEffects =>
      '3 efeitos ao mesmo tempo: não medido no telefone de referência';

  @override
  String get studioQaBlocked => 'Corrija os itens em vermelho para publicar.';

  @override
  String get studioLayerIris => 'Íris (lentes coloridas)';
}

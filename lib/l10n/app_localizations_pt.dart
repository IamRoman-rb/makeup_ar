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
  String get changePasswordDesc => 'Digite sua senha atual e escolha uma nova.';

  @override
  String get dangerZone => 'Zona de Perigo';

  @override
  String get deleteAccount => 'Excluir Conta';

  @override
  String get deleteAccountDesc =>
      'São apagados deste telefone sua conta, seu perfil, sua foto, seus looks salvos e Meus looks. Não é possível desfazer. Se você tem VIP, excluir a conta não cancela a assinatura: cancele-a na loja.';

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
  String get viewTutorial => 'Ver tutorial';

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

  @override
  String get myAiLooksTitle => 'Meus looks com IA';

  @override
  String get myAiLooksPromptHint =>
      'Descreva o look (ex.: lábios vermelhos e delineado gráfico)';

  @override
  String myAiLooksDailyLimit(int count) {
    return 'Até $count por dia';
  }

  @override
  String get myAiLooksGenerate => 'Gerar';

  @override
  String get myAiLooksVariants => 'Escolha uma variante';

  @override
  String get myAiLooksSuggestion => 'Sugestão';

  @override
  String get myAiLooksTry => 'Experimentar';

  @override
  String get myAiLooksSave => 'Salvar';

  @override
  String get myAiLooksSaved => 'Salvo nos seus looks';

  @override
  String get myAiLooksSavedTitle => 'Salvos';

  @override
  String get myAiLooksEmpty => 'Você ainda não salvou looks com IA.';

  @override
  String get myAiLooksDelete => 'Excluir';

  @override
  String myAiLooksDeleteConfirm(String name) {
    return 'Excluir \"$name\"?';
  }

  @override
  String myAiLooksErrorQuota(int count) {
    return 'Você atingiu o limite de $count looks hoje. Tente amanhã.';
  }

  @override
  String myAiLooksErrorFull(int count) {
    return 'Você já tem $count looks salvos. Exclua um para salvar outro.';
  }

  @override
  String get myAiLooksErrorLogin => 'Entre na sua conta para criar looks.';

  @override
  String get myAiLooksErrorGeneric =>
      'Não foi possível concluir. Tente novamente.';

  @override
  String get myAiLooksFallback =>
      'A IA não respondeu: sugerimos um look parecido.';

  @override
  String myAiLooksInvalidPrompt(int max) {
    return 'Escreva entre 1 e $max caracteres.';
  }

  @override
  String loginError(String details) {
    return 'Não foi possível entrar: $details';
  }

  @override
  String errorWithDetails(String details) {
    return 'Erro: $details';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get catalogCreateLookTooltip => 'Criar look (admin)';

  @override
  String catalogLoadError(String details) {
    return 'Erro ao carregar os looks: $details';
  }

  @override
  String get filterEditorNewTitle => 'Novo look';

  @override
  String get filterEditorEditTitle => 'Editar look';

  @override
  String get filterEditorDefaultName => 'Novo look';

  @override
  String get filterEditorSaved => 'Look salvo com sucesso! 🚀';

  @override
  String filterEditorSaveError(String details) {
    return 'Não foi possível salvar o look: $details';
  }

  @override
  String get filterEditorDeleteTitle => 'Excluir look?';

  @override
  String get filterEditorDeleteBody => 'Esta ação não pode ser desfeita.';

  @override
  String get filterEditorDeleted => 'Look excluído 🗑️';

  @override
  String get filterEditorAdminOnly =>
      'Só um administrador pode criar ou editar looks.';

  @override
  String get filterEditorDeleteTooltip => 'Excluir look';

  @override
  String get filterEditorName => 'Nome do look';

  @override
  String get filterEditorCategory => 'Categoria';

  @override
  String get filterEditorCoverUrl => 'URL da imagem de capa (opcional)';

  @override
  String get filterEditorVideoUrl =>
      'URL do vídeo do tutorial (opcional, só VIP)';

  @override
  String get filterEditorSteps => 'Passos do tutorial';

  @override
  String get filterEditorAddStep => 'Adicionar passo';

  @override
  String get filterEditorNoSteps => 'Ainda não há passos.';

  @override
  String filterEditorStep(int number) {
    return 'Passo $number';
  }

  @override
  String get filterEditorRemoveStep => 'Remover passo';

  @override
  String get filterEditorStepTitle => 'Título';

  @override
  String get filterEditorStepImage => 'URL da imagem (opcional)';

  @override
  String get filterEditorStepDescription => 'Descrição / instruções';

  @override
  String get stepsEmpty => 'Ainda não há passos para este look.';

  @override
  String get tutorialNoVideoTitle => 'Sem vídeo para este look';

  @override
  String get tutorialNoVideoBody =>
      'Ainda não enviamos um vídeo para este tutorial.';

  @override
  String get tutorialVipTitle => 'Tutorial VIP';

  @override
  String get tutorialVipBody => 'Desbloqueie os segredos deste look.';

  @override
  String get becomeVip => 'Seja VIP';

  @override
  String profileLoadError(String details) {
    return 'Erro ao carregar o perfil: $details';
  }

  @override
  String get profileNoData => 'Não encontramos os dados do seu perfil.';

  @override
  String profilePreferences(String list) {
    return 'Preferências: $list';
  }

  @override
  String get profileDefaultBio =>
      'Explorando estéticas elegantes e minimalistas.';

  @override
  String get skinTypeCombined => 'Mista';

  @override
  String get skinTypeOily => 'Oleosa';

  @override
  String get skinTypeDry => 'Seca';

  @override
  String get skinTypeSensitive => 'Sensível';

  @override
  String get skinToneLight => 'Clara';

  @override
  String get skinToneMedium => 'Média';

  @override
  String get skinToneTan => 'Morena';

  @override
  String get skinToneDeep => 'Escura';

  @override
  String get prefNatural => 'Natural';

  @override
  String get prefGlamour => 'Glamour';

  @override
  String get prefMinimalist => 'Minimalista';

  @override
  String get prefBold => 'Ousado';

  @override
  String get prefSkincare => 'Foco em skincare';

  @override
  String get vipUnavailable => 'O VIP não está disponível nesta versão.';

  @override
  String vipLoadError(String details) {
    return 'Não foi possível carregar os planos VIP.\n$details';
  }

  @override
  String get vipPurchased => 'Pronto, você é VIP! 🎉 Ativa em alguns segundos.';

  @override
  String vipPurchaseError(String details) {
    return 'Não foi possível concluir a compra: $details';
  }

  @override
  String get vipRestored =>
      'Encontramos sua assinatura VIP! 🎉 Ativa em alguns segundos.';

  @override
  String get vipNothingToRestore => 'Não encontramos compras para restaurar.';

  @override
  String get vipRestore => 'Restaurar compras';

  @override
  String get vipNoPlans => 'Ainda não há nenhum plano VIP configurado.';

  @override
  String get vipHeadline =>
      'Desbloqueie os vídeos dos tutoriais que os incluem';

  @override
  String get signupPhotoFailed =>
      'Sua conta foi criada, mas não conseguimos salvar a foto. Você pode adicioná-la depois pelo seu perfil.';

  @override
  String get startupError =>
      'Não foi possível iniciar o app. Verifique sua conexão.';

  @override
  String get commonRetry => 'Tentar de novo';

  @override
  String get coachGuideMe => 'Me guie';

  @override
  String get coachTitle => 'Guia de maquiagem';

  @override
  String get coachIntroTitle => 'Antes de começar';

  @override
  String get coachIntroBody =>
      'Para mais precisão, comece com o rosto limpo e tire uma referência. Tudo é medido no celular: nenhuma imagem é salva ou enviada.';

  @override
  String get coachTakeReference => 'Tirar referência';

  @override
  String get coachSkip => 'Pular';

  @override
  String get coachTakingReference => 'Fique parada olhando para a câmera…';

  @override
  String get coachReferenceFailed =>
      'Não foi possível tirar a referência. Seguimos sem ela.';

  @override
  String get coachHoldTarget => 'Segure para ver o look';

  @override
  String get coachMute => 'Silenciar';

  @override
  String get coachUnmute => 'Ativar voz';

  @override
  String get coachVoiceUnavailable =>
      'Seu celular não tem voz para este idioma: as dicas ficam na tela.';

  @override
  String get coachNoZones =>
      'Este look não tem áreas que o guia possa revisar.';

  @override
  String get coachStarting => 'Olhe para a câmera para começar.';

  @override
  String get coachDone => 'Pronto! Sua maquiagem combina com o look.';

  @override
  String get coachLookAtCamera => 'Olhe de frente para a câmera.';

  @override
  String get coachComeCloser => 'Chegue um pouco mais perto da câmera.';

  @override
  String get coachMoreLight => 'Falta luz: procure uma luz uniforme no rosto.';

  @override
  String coachVerdictOk(String zone) {
    return '$zone: ótimo!';
  }

  @override
  String coachTooLittle(String zone) {
    return '$zone: falta cor, aplique um pouco mais.';
  }

  @override
  String coachTooMuch(String zone) {
    return '$zone: tem demais, esfume ou tire um pouco.';
  }

  @override
  String coachTooDark(String zone) {
    return '$zone: ficou mais escuro que o look.';
  }

  @override
  String coachTooLight(String zone) {
    return '$zone: ficou mais claro que o look.';
  }

  @override
  String coachOtherTone(String zone) {
    return '$zone: o tom não é o do look.';
  }

  @override
  String coachNotVisible(String zone) {
    return '$zone: não dá para ver bem, vire um pouco para a câmera.';
  }

  @override
  String get coachLinerMissing =>
      'Delineado: falta, marque a linha dos cílios.';

  @override
  String get coachLinerThin => 'Delineado: ficou fino, engrosse um pouco.';

  @override
  String get coachLinerThick => 'Delineado: ficou grosso, afine.';

  @override
  String get coachWingShort =>
      'Delineado: o gatinho ficou curto, alongue para fora.';

  @override
  String get coachWingLong => 'Delineado: o gatinho ficou longo, encurte.';

  @override
  String get coachLinerTooFar =>
      'Chegue mais perto da câmera para revisar o delineado.';

  @override
  String get coachStepsTitle => 'Passos do look';

  @override
  String get coachStepsIntro =>
      'Não foi possível abrir a câmera para te acompanhar. Siga os passos em ordem e toque em “Feito” ao terminar cada um.';

  @override
  String coachStepColor(String zone, String amount) {
    return '$zone: aplique a cor da amostra $amount.';
  }

  @override
  String get coachAmountLight => 'em uma camada leve';

  @override
  String get coachAmountMedium => 'em quantidade média';

  @override
  String get coachAmountStrong => 'com boa cobertura';

  @override
  String coachStepLiner(String width) {
    return 'Delineado: marque a linha dos cílios com um traço $width.';
  }

  @override
  String coachStepLinerWing(String width) {
    return 'Delineado: marque a linha dos cílios com um traço $width e termine com um gatinho para fora.';
  }

  @override
  String get coachLinerWidthThin => 'fino';

  @override
  String get coachLinerWidthMedium => 'médio';

  @override
  String get coachLinerWidthThick => 'grosso';

  @override
  String coachStepProgress(int current, int total) {
    return 'Passo $current de $total';
  }

  @override
  String get coachStepNext => 'Feito, próximo';

  @override
  String get coachStepBack => 'Anterior';

  @override
  String get coachStepsFinished => 'Você terminou todos os passos do look!';

  @override
  String get coachStepsRestart => 'Começar de novo';

  @override
  String get coachZoneLips => 'Lábios';

  @override
  String get coachZoneLipLiner => 'Contorno labial';

  @override
  String get coachZoneCheeks => 'Blush';

  @override
  String get coachZoneEyeLiner => 'Delineado';

  @override
  String get coachZoneShadowLid => 'Sombra da pálpebra';

  @override
  String get coachZoneShadowCrease => 'Sombra do côncavo';

  @override
  String get coachZoneShadowOuterV => 'Sombra no V externo';

  @override
  String get coachZoneShadowInnerCorner => 'Canto interno';

  @override
  String get coachZoneShadowBrowBone => 'Abaixo da sobrancelha';

  @override
  String get studioLocalOnly =>
      'A IA ainda não está conectada: mostramos o preset mais parecido com o seu pedido.';

  @override
  String get myAiLooksLocalOnly =>
      'A IA ainda não está conectada: sugerimos um look parecido.';

  @override
  String get authErrorInvalidEmail => 'O e-mail não é válido.';

  @override
  String authErrorWeakPassword(int min) {
    return 'A senha deve ter pelo menos $min caracteres.';
  }

  @override
  String get authErrorEmailInUse => 'Já existe uma conta com esse e-mail.';

  @override
  String get authErrorWrongCredentials => 'E-mail ou senha incorretos.';

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get newPassword => 'Nova senha';

  @override
  String get passwordChanged => 'Senha alterada.';

  @override
  String get changeBtn => 'Alterar';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get termsOfService => 'Termos e condições';

  @override
  String get thirdPartyLicenses => 'Licenças de terceiros';

  @override
  String get legalDraftBanner =>
      'RASCUNHO — não publicar: faltam dados do responsável ou a revisão jurídica.';

  @override
  String get legalLoadError => 'Não foi possível abrir o documento.';

  @override
  String get privacyCenterTitle => 'Privacidade e dados';

  @override
  String get privacyCenterIntro =>
      'Sua conta e seu perfil ficam guardados só neste telefone. A câmera e as fotos que você escolhe são processadas no telefone e não são enviadas.';

  @override
  String get privacyYourData => 'Seus dados neste telefone';

  @override
  String get privacyCopyData => 'Copiar meus dados';

  @override
  String get privacyDataCopied =>
      'Seus dados foram copiados para a área de transferência.';

  @override
  String get privacyRightsTitle => 'Seus direitos';

  @override
  String privacyRightsBody(String contact) {
    return 'Aqui você pode ver e copiar seus dados; corrigi-los em Editar perfil e apagá-los com Excluir conta. Para outros pedidos escreva para: $contact';
  }

  @override
  String get manageSubscription => 'Gerenciar ou cancelar a assinatura';

  @override
  String get manageSubscriptionAndroid =>
      'Abra o Google Play > seu perfil > Pagamentos e assinaturas > Assinaturas, escolha este app e toque em Cancelar assinatura.';

  @override
  String get manageSubscriptionIos =>
      'Abra Ajustes > seu nome > Assinaturas, escolha este app e toque em Cancelar Assinatura.';

  @override
  String get manageSubscriptionNote =>
      'Excluir a conta ou desinstalar o app não cancela a assinatura.';

  @override
  String get manageSubscriptionLink => 'Link da loja';

  @override
  String get copyLink => 'Copiar link';

  @override
  String get linkCopied => 'Link copiado.';

  @override
  String get signupAcceptLegal =>
      'Li e aceito a política de privacidade e os termos e condições.';

  @override
  String get signupMustAccept =>
      'Para criar a conta você precisa aceitar a política de privacidade e os termos.';

  @override
  String signupUnderMinimumAge(int age) {
    return 'Para criar uma conta você precisa ter pelo menos $age anos.';
  }

  @override
  String get signupLocalNotice =>
      'Sua conta fica guardada só neste telefone. Sem servidor não há recuperação de senha por e-mail.';

  @override
  String get profilePhotoNotice =>
      'Opcional. Fica só neste telefone, reduzida e sem dados de localização.';

  @override
  String get profilePhotoA11y => 'Foto de perfil. Toque para trocá-la.';

  @override
  String get removePhoto => 'Remover foto';

  @override
  String get deleteAccountPartial =>
      'Sua conta foi excluída, mas não foi possível remover a foto de perfil. Desinstalar o app a apaga.';

  @override
  String get deleteAccountError =>
      'Não foi possível excluir a conta. Nada foi alterado; tente de novo.';

  @override
  String vipPricePerPeriod(String price, String period) {
    return '$price a cada $period';
  }

  @override
  String vipOneTime(String price) {
    return '$price, pagamento único';
  }

  @override
  String vipFreeTrial(String duration) {
    return 'Teste grátis: $duration';
  }

  @override
  String vipIntroOffer(String price, String duration) {
    return 'Preço promocional: $price por $duration';
  }

  @override
  String vipAutoRenewNotice(String store) {
    return 'As assinaturas são renovadas automaticamente ao fim de cada período, pelo preço indicado, até você cancelá-las em $store. A cobrança é feita na sua conta $store ao confirmar a compra. Cancele antes da renovação para não ser cobrado pelo período seguinte. Excluir a conta ou o app não cancela a assinatura.';
  }

  @override
  String vipPeriodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: 'dia',
    );
    return '$_temp0';
  }

  @override
  String vipPeriodWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas',
      one: 'semana',
    );
    return '$_temp0';
  }

  @override
  String vipPeriodMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: 'mês',
    );
    return '$_temp0';
  }

  @override
  String vipPeriodYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anos',
      one: 'ano',
    );
    return '$_temp0';
  }

  @override
  String get cameraRationaleTitle => 'Acesso à câmera';

  @override
  String get cameraRationaleBody =>
      'A câmera mostra ao vivo a maquiagem virtual e o guia de maquiagem. As imagens são processadas neste telefone: não são gravadas nem enviadas.';

  @override
  String get cameraRationaleContinue => 'Continuar';

  @override
  String get cameraRationaleNotNow => 'Agora não';

  @override
  String get cameraDeniedBody =>
      'Sem acesso à câmera não é possível mostrar a maquiagem ao vivo. Você pode permitir quando quiser.';

  @override
  String get cameraAllow => 'Permitir câmera';

  @override
  String get cameraOpenSettings => 'Abrir ajustes';
}

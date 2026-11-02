# Política de privacidade (RASCUNHO)

Vigência: {{effectiveDate}}. Este texto é um rascunho técnico que descreve o que o app faz. Não é assessoria jurídica e deve ser revisado por um advogado antes da publicação. Prevalece a versão em espanhol. [REVISAR: idioma prevalente.]

## Responsável

{{controllerName}}, CUIT {{controllerTaxId}}, com endereço em {{controllerAddress}}. Contato para assuntos de dados pessoais: {{privacyEmail}}.

## Onde seus dados ficam guardados

O app não tem servidor próprio. Sua conta, seu perfil, seus looks salvos e sua foto de perfil ficam guardados só neste telefone, no armazenamento privado do app. Não os enviamos a nenhum servidor nosso.

## Quais dados usamos e para quê

- Conta: e-mail, nome, data de nascimento e uma senha guardada de forma transformada (hash PBKDF2), nunca em texto claro. Servem para abrir sua conta neste telefone e calcular sua idade.
- Perfil (opcional): tipo e tom de pele e preferências de maquiagem. Servem para personalizar o app. [REVISAR: se o tom de pele pode ser considerado dado sensível segundo o art. 2 da Lei 25.326 e qual consentimento exige.]
- Foto de perfil (opcional): você a escolhe na galeria. Guardamos uma cópia reduzida e sem metadados (localização, câmera, data) na pasta do app.
- Câmera ao vivo: a imagem é processada no telefone para localizar pontos do rosto (olhos, lábios, contorno) e desenhar a maquiagem virtual. Nenhuma foto ou vídeo é gravado, nada é enviado e a imagem não é usada para reconhecer quem você é: não são criados modelos para identificar pessoas.
- Guia de maquiagem: mede cores e posições do seu rosto no telefone durante a sessão. Nenhuma imagem é guardada.
- Fotos de referência e de produto (Studio): analisadas no telefone; ficam só números (cores e intensidades). A foto não é guardada nem enviada. Use fotos suas ou com permissão da pessoa que aparece.
- Looks salvos e "Meus looks": as receitas de maquiagem que você salva.

## Terceiros que recebem dados

- Compras VIP: os pagamentos são processados pelo Google Play ou pela App Store; o app não vê os dados do seu cartão. Para saber se você tem VIP usamos a RevenueCat, Inc., que recebe um identificador aleatório da sua conta (não seu e-mail nem seu nome), os dados da compra e dados técnicos do dispositivo. [REVISAR: transferência internacional de dados (art. 12 Lei 25.326) e contrato com o fornecedor.]
- Fontes: o app baixa suas fontes dos servidores do Google Fonts na primeira vez que as usa. O Google recebe o endereço IP e dados técnicos da solicitação.
- Imagens e vídeos do catálogo: se um look tem uma imagem ou um vídeo hospedado na internet, o servidor que o hospeda recebe seu endereço IP ao exibi-lo.
- Backup do sistema: se o backup do Android ou do iCloud estiver ativado, o sistema operacional pode incluir os dados do app no seu backup, na sua conta Google ou Apple.

Não vendemos seus dados nem os usamos para publicidade. O app não inclui ferramentas de análise nem de publicidade.

## Consentimento

Ao criar a conta você aceita esta política. Você pode retirar seu consentimento a qualquer momento excluindo sua conta. [REVISAR: forma do consentimento segundo os arts. 5 e 6 da Lei 25.326.]

## Por quanto tempo são guardados

- No telefone: enquanto sua conta existir. Ao excluir a conta, são apagados seu perfil, sua foto, seus looks salvos e "Meus looks". Se você desinstalar o app, o sistema apaga os dados dele.
- A RevenueCat e as lojas guardam os registros de compras segundo suas próprias políticas. Para pedir a exclusão, escreva para {{privacyEmail}}. [COMPLETAR: prazo e procedimento acordados com a RevenueCat.]

## Seus direitos

Você pode acessar, retificar, atualizar e pedir a exclusão dos seus dados (arts. 14, 15 e 16 da Lei 25.326):

- No app: Perfil > Privacidade e dados (ver e copiar seus dados), Editar perfil (corrigir) e Configurações da conta > Excluir conta (apagar).
- Por e-mail para {{privacyEmail}}.

O titular dos dados pessoais tem a faculdade de exercer o direito de acesso a eles gratuitamente em intervalos não inferiores a seis meses, salvo se for comprovado um interesse legítimo, conforme o artigo 14, inciso 3 da Lei N° 25.326. A Agência de Acesso à Informação Pública, como Órgão de Controle da Lei N° 25.326, tem a atribuição de atender às denúncias e reclamações de quem for afetado em seus direitos pelo descumprimento das normas de proteção de dados pessoais. [REVISAR: texto vigente da legenda exigida pela AAIP e inscrição da base de dados.]

## Menores de idade

Para criar uma conta é preciso ter pelo menos {{minimumAge}} anos. [REVISAR: idade mínima, consentimento de pais ou responsáveis (art. 26 do Código Civil e Comercial) e Lei 26.061.]

## Segurança

Os dados ficam no armazenamento privado do app, ao qual outros apps não têm acesso. A senha é guardada com hash e sal. O banco de dados do telefone não é criptografado à parte: quem desbloquear seu telefone ou tiver acesso de administrador (root) poderia lê-lo. Use um bloqueio de tela.

## Alterações

Se mudarmos esta política, publicaremos a nova versão com sua data de vigência. [REVISAR: como se avisa e se é preciso pedir a aceitação de novo; hoje o app não guarda qual versão você aceitou.]

## Contato

{{controllerName}} · {{privacyEmail}} · Suporte: {{supportContact}}

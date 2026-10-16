/** Envia e-mails transacionais via Resend sem expor tokens ou códigos em logs. */
export async function sendEmail(config, message) {
  if (!config.resendToken || !config.mailFrom)
    throw Object.assign(
      new Error("E-mail transacional ainda não configurado."),
      {
        status: 503,
      },
    );
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.resendToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: config.mailFrom, ...message }),
  });
  if (!response.ok)
    throw Object.assign(
      new Error("Não foi possível enviar o e-mail. Tente novamente."),
      {
        status: 503,
      },
    );
}

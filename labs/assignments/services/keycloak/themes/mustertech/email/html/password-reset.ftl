<#assign body>
  <p>Hallo ${user.firstName!"Benutzer"},</p>

  <p>Sie haben eine Anfrage zum Zur&uuml;cksetzen Ihres Passworts gestellt.</p>

  <p style="text-align: center; margin: 24px 0;">
    <a href="${link}" style="display: inline-block; padding: 12px 32px; background-color: #0066cc; color: #ffffff; text-decoration: none; border-radius: 4px; font-weight: 600;">
      Passwort zur&uuml;cksetzen
    </a>
  </p>

  <p>Dieser Link ist ${linkExpirationFormatter(linkExpiration)} g&uuml;ltig.</p>

  <p>Falls Sie diese Anfrage nicht gestellt haben, ignorieren Sie diese E-Mail.</p>
</#assign>

<#include "template.ftl">

<#assign body>
  <p>${kcSanitize(msg("emailTestBodyHtml", realmName))?no_esc}</p>
</#assign>

<#include "template.ftl">

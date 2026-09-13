// Nur der Ressourcenbesitzer darf die delete-Permission erhalten.
var context = $evaluation.getContext();
var identity = context.getIdentity();
var resource = $evaluation.getPermission().getResource();

if (resource.getOwner().equals(identity.getId())) {
    $evaluation.grant();
}

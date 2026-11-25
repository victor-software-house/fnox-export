DEMO_FNOX='[providers]
plain = { type = "plain" }

[profiles.demo.secrets]
ALPHA_TOKEN = { default = "alpha-value" }
BETA_TOKEN  = { default = "beta-value" }
GAMMA_RAW   = { default = "gamma-value" }
SERVICE_FOO  = { default = "service-foo" }
SERVICE_BAR  = { default = "service-bar" }
FROM        = { default = "from-upper" }
'

EMPTY_FNOX='[providers]
plain = { type = "plain" }

[profiles.empty.secrets]
'

MULTI_FNOX='[providers]
plain = { type = "plain" }

[profiles.base.secrets]
SHARED_KEY = { default = "base-value" }
ONLY_BASE  = { default = "base-only" }

[profiles.overlay.secrets]
SHARED_KEY = { default = "overlay-value" }
ONLY_OVER  = { default = "overlay-only" }
'

THREE_FNOX='[providers]
plain = { type = "plain" }

[profiles.first.secrets]
SHARED_KEY = { default = "first-value" }
ONLY_FIRST = { default = "first-only" }

[profiles.second.secrets]
SHARED_KEY = { default = "second-value" }
ONLY_SECOND = { default = "second-only" }

[profiles.third.secrets]
SHARED_KEY = { default = "third-value" }
ONLY_THIRD = { default = "third-only" }
'

DEFAULT_FNOX='[providers]
plain = { type = "plain" }

[secrets]
DEFAULT_TOKEN = { default = "default-value" }
'

# Secrets resolved through password-store, whose `pass` binary the named-keys
# tests replace with a logging stub that fails: a call to it means fnox resolved
# that secret.
NAMED_FNOX='[providers]
plain = { type = "plain" }
store = { type = "password-store" }

[profiles.named.secrets]
ALPHA_TOKEN = { default = "alpha-value" }
BETA_TOKEN  = { default = "beta-value" }
SERVICE_FOO = { default = "service-foo" }

[profiles.named.secrets.BROKEN]
provider = "store"
value = "broken/entry"
'

NAMED_MULTI_FNOX='[providers]
plain = { type = "plain" }
store = { type = "password-store" }

[profiles.left.secrets]
LEFT_ONLY  = { default = "left-value" }
SHARED_KEY = { default = "left-shared" }

[profiles.left.secrets.LEFT_BROKEN]
provider = "store"
value = "left/entry"

[profiles.right.secrets]
RIGHT_ONLY = { default = "right-value" }

[profiles.right.secrets.RIGHT_BROKEN]
provider = "store"
value = "right/entry"
'

# FIXME:
# with cparser,
#   Temill.show(
#     55
#   )
# results in
#   Temill.show(
#     55
#   # temill showing 1 results for line 1 (line 1 in this output)
#   # 55
#   )
# ,which is not what we want.
Racc_No_Extensions = true

require "temill/version"
require 'temill/core'
require 'temill/parser'
require 'temill/emitter'

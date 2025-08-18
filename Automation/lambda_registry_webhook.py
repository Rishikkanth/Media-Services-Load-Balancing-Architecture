def register(node_id, path, tg_arn):
  # look up rule for path, ensure weight to TG >= 1
  elbv2.modify_rule(...set weight...)

def deregister(node_id, path, tg_arn):
  elbv2.modify_rule(...set weight 0 for that TG...)


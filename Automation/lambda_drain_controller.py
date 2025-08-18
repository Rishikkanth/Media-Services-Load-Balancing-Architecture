import os, time, json, boto3

dynamodb = boto3.resource('dynamodb')
elbv2 = boto3.client('elbv2')
ecs = boto3.client('ecs')

REGISTRY = dynamodb.Table(os.environ['REGISTRY_TABLE'])
MAX_DRAIN_SECS = int(os.getenv("MAX_DRAIN_SECS", "7200"))  # 2h

def _get_status(node_id):
    return REGISTRY.get_item(Key={"node_id": node_id}).get("Item", {})

def _update_status(node_id, status):
    REGISTRY.update_item(
        Key={"node_id": node_id},
        UpdateExpression="SET #s=:s",
        ExpressionAttributeNames={"#s":"status"},
        ExpressionAttributeValues={":s": status}
    )

def handler(event, ctx):
    """
    event example:
    {
      "node_id": "ip-10-0-3-42",
      "path": "/media/1/*",
      "target_group_arn": "arn:aws:elasticloadbalancing:...:targetgroup/...",
      "ecs_cluster": "media-cluster",
      "ecs_task_arn": "arn:aws:ecs:...:task/..."
    }
    """
    node_id = event["node_id"]
    tg_arn  = event["target_group_arn"]
    ecs_task = event["ecs_task_arn"]

    _update_status(node_id, {"S":"DRAINING"})
    start = time.time()

    while time.time() - start < MAX_DRAIN_SECS:
        item = _get_status(node_id)
        active = int(item.get("active_connections", "0"))
        if active == 0:
            # clean drain
            # (Optionally: elbv2.deregister_targets(TargetGroupArn=tg_arn, Targets=[{"Id": node_ip, "Port": 4001}]))
            ecs.stop_task(cluster=event["ecs_cluster"], task=ecs_task)
            _update_status(node_id, {"S":"STOPPED"})
            return {"result":"clean-drain"}
        time.sleep(30)

    # Force close path (your app should offer admin endpoint to close sockets)
    # requests.post(f"http://{node_internal_host}:4001/admin/force-close")
    ecs.stop_task(cluster=event["ecs_cluster"], task=ecs_task)
    _update_status(node_id, {"S":"STOPPED_FORCE"})
    return {"result":"forced"}


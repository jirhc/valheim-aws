import json
import boto3
import os
from nacl.signing import VerifyKey
from aws_lambda_powertools import Logger

sns_client = boto3.client('sns')

logger = Logger()

''' public key found on Discord Application -> General Information page '''
DISCORD_PUBLIC_KEY = os.getenv('DISCORD_PUBLIC_KEY')

PING_PONG = {"type": 1}

RESPONSE_TYPES = {
    "PONG": 1,
    "CHANNEL_MESSAGE_WITH_SOURCE": 4,
    "DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE": 5,
    "DEFERRED_UPDATE_MESSAGE": 6,
    "UPDATE_MESSAGE": 7,
    "APPLICATION_COMMAND_AUTOCOMPLETE_RESULT": 8,
    "MODAL": 9,
}

def verifyEvent(signature: str, timestamp: str, body: str) -> None:
    '''Verifies that an event coming from Discord is legitimate. 
    Raises an Exception if the verification fails.
    '''
    message = timestamp.encode() + body.encode()
    verify_key = VerifyKey(bytes.fromhex(DISCORD_PUBLIC_KEY))
    verify_key.verify(message, bytes.fromhex(signature)) # raises an error if unequal


def lambda_handler(event, context):
    '''Handles incoming events from the Discord bot (HTTP API v2 proxy format).'''
    logger.debug(f"Received event: {json.dumps(event, indent=4)}")

    # HTTP API v2 sends headers and raw body differently than REST API
    headers = event.get('headers', {})
    raw_body = event.get('body', '{}')
    
    signature = headers.get('x-signature-ed25519', '')
    timestamp = headers.get('x-signature-timestamp', '')

    # verify the signature
    try:
        verifyEvent(signature, timestamp, raw_body)
    except Exception as e:
        logger.error(f"Signature verification failed: {e}")
        return {
            "statusCode": 401,
            "body": json.dumps({"error": "invalid request signature"})
        }

    # parse the body
    body = json.loads(raw_body)
    
    # check if message is a ping
    if body.get("type") == 1:
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(PING_PONG)
        }
    
    cmd_name = body.get("data", {}).get("name")
    
    # Build the internal event payload for the vhserver lambda (via SNS)
    internal_event = {
        "timestamp": timestamp,
        "signature": signature,
        "jsonBody": body
    }
    
    sns_client.publish(
        TargetArn=os.environ['SNS_PUBLISH_VH_ARN'],
        Message=json.dumps({
            "default": json.dumps(internal_event)
            }),
        MessageStructure='json',
        MessageAttributes= {
            "command": { 
                'DataType': 'String', 
                'StringValue': cmd_name 
                } 
            }
    )

    # ACK the initial command, the "command" lambda will takeover the real answer.
    ret = {"type": RESPONSE_TYPES['DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE']}
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(ret)
    }

###############################################################################
## TEST
if __name__ == '__main__':
    pass
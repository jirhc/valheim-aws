from dataclasses import dataclass
import json
from typing import Optional
import requests
import os
import boto3
from aws_lambda_powertools import Logger

DISCORD_AUTH_TOKEN = os.getenv('DISCORD_AUTH_TOKEN')
DISCORD_APP_ID = os.getenv('DISCORD_APP_ID')

CURRENT_API_VERSION = "10"

logger = Logger()

RESPONSE_TYPES = {
    "PONG": 1,
    "CHANNEL_MESSAGE_WITH_SOURCE": 4,
    "DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE": 5,
    "DEFERRED_UPDATE_MESSAGE": 6,
    "UPDATE_MESSAGE": 7,
    "APPLICATION_COMMAND_AUTOCOMPLETE_RESULT": 8,
    "MODAL": 9,
}

@dataclass
class IDiscordRole:
    """A server role assigned to a user."""
    id: str
    name: str
    color: int
    hoist: bool
    mentionable: bool

@dataclass
class IDiscordUser:
    """The user information for a Discord member."""
    id: int
    username: str
    discriminator: str

@dataclass
class IDiscordMember:
    """A Discord member and their properties."""
    deaf: bool
    roles: list[str]
    user: IDiscordUser

@dataclass
class IDiscordRequestDataOption:
    """The name and value for a given command option if available."""
    name: str
    value: str

@dataclass
class IDiscordEndpointInfo:
    """The information for the endpoint to use when sending a response.

    Default version for the API version is 8 when not specified.
    """
    apiVersion: Optional[str]
    authToken: str
    applicationId: str

@dataclass
class IDiscordRequestData:
    """The data in the Discord request. Should be handled for actually parsing commands."""
    id: str
    name: str
    options: Optional[list[IDiscordRequestDataOption]]

@dataclass
class IDiscordJsonBody:
    """The actual Discord request data."""
    id: Optional[str]
    token: Optional[str]
    data: Optional[IDiscordRequestData]
    member: Optional[IDiscordMember]
    type: int
    version: int

@dataclass
class IDiscordEventRequest:
    """The incoming request, created via API Gateway request templates."""
    timestamp: str
    signature: str
    jsonBody: IDiscordJsonBody

@dataclass
class IDiscordResponseData:
    """The actual response data that will be used in the resulting Discord message."""
    tts: bool
    content: str
    embeds: list
    allowedMentions: list[str]

def sendFollowupMessage(endpointInfo: IDiscordEndpointInfo,
                        interactionToken: str, responseData: IDiscordResponseData) -> bool:
    """Send a followup message to Discord's APIs on behalf of the bot.

    @param endpointInfo The information to use when talking to the endpoint.
    @param interactionToken The token representing the interaction to follow up on.
    @param responseData The response data to be sent to the Discord server.
    @returns Returns true if the response was succesfully sent, false otherwise.
    """
    headers = {
        'Authorization': f"Bot {endpointInfo.authToken}",
    }
    data = {
        "allowedMentions": responseData.allowedMentions,
        "tts": responseData.tts,
        "content": responseData.content,
        "embeds": responseData.embeds,
    }

    apiVersion = endpointInfo.apiVersion if endpointInfo.apiVersion is not None else CURRENT_API_VERSION
    
    logger.debug(f"Response: {responseData}")

    try:
        url = f"https://discord.com/api/v{apiVersion}/webhooks/{endpointInfo.applicationId}/{interactionToken}"
        logger.debug(url)
        r = requests.post(url, headers=headers, json=data)
        logger.debug(r)
        return r.status_code == 200
    except requests.exceptions.RequestException as e:
        logger.error(f"There was an error posting a response: {e}")
        return False

###############################################################################
# command options function

# ec2 = boto3.resource('ec2', region_name='ap-southeast-2')
ec2 = boto3.client('ec2')
SERVER_INSTANCE_ID = os.getenv('SERVER_INSTANCE_ID')

VH_OPTIONS = ["status", "start", "stop"]

## STATUS
def vh_status(endpointInfo, token):
    instance = ec2.describe_instances(InstanceIds = [SERVER_INSTANCE_ID])
    status = instance['Reservations'][0]['Instances'][0]['State']['Name']
    network_interface = instance['Reservations'][0]['Instances'][0]['NetworkInterfaces'][0]
    dns = ""
    ip = ""
    if (network_interface.get('Association') is not None):
        dns = network_interface['Association']['PublicDnsName']
        ip = network_interface['Association']['PublicIp']
    
    content = None
    if (status == "running"):
        content = f"""
Server status: {status}
Valheim connection using the public DNS: {dns}:2456
Valheim connection using the public IPv4 address: {ip}:2456
"""
    else:
        content = f"Server status: {status}"
    
    # response = ec2.describe_instance_status(InstanceIds=[SERVER_INSTANCE_ID])
    # status = response['InstanceStatuses'][0]['InstanceState']['Name']
        
    logger.info(content)
    response = IDiscordResponseData(
        tts = False,
        content = content,
        embeds = [],
        allowedMentions = [],
    )
    return sendFollowupMessage(endpointInfo, token, response)

## START
def vh_start(endpointInfo, token):
    ec2.start_instances(InstanceIds = [SERVER_INSTANCE_ID])
    logger.info(f"Starting EC2 instance {SERVER_INSTANCE_ID}...")
    response = IDiscordResponseData(
        tts = False,
        content = "Starting the Valheim server... check the server status with \'/vh status\' in the a couple of minutes.",
        embeds = [],
        allowedMentions = [],
    )
    return sendFollowupMessage(endpointInfo, token, response)

## STOP
def vh_stop(endpointInfo, token):
    ec2.stop_instances(InstanceIds = [SERVER_INSTANCE_ID])
    logger.info(f"Stopping EC2 instance {SERVER_INSTANCE_ID}...")
    response = IDiscordResponseData(
        tts = False,
        content = "Stopping the Valheim server... check the server status with \'/vh status\' in the a couple of minutes. Anyway it should stop by itself automatically if nobody is connected in the Valheim World :-p .",
        embeds = [],
        allowedMentions = [],
    )
    return sendFollowupMessage(endpointInfo, token, response)

###############################################################################
# handler

def lambda_handler(event, context):
    """lambda_handler(event, context)
    """
    logger.debug(f"Received event: {json.dumps(event, indent=2)}")

    endpointInfo = IDiscordEndpointInfo (
        authToken = DISCORD_AUTH_TOKEN,
        applicationId = DISCORD_APP_ID,
        apiVersion = CURRENT_API_VERSION
    )
    
    # retreive message as dict
    m = event['Records'][0]['Sns']['Message']
    message = json.loads(m)
    
    # response template
    response = IDiscordResponseData(
        tts = False,
        content = "Hello world!",
        embeds = [],
        allowedMentions = [],
    )
    
    # get the body
    body = message.get('jsonBody')
       
    # check token
    token = body.get('token')
    if (token is None):
        logger.error(f"Invalid request: Token not found")
        return -1
        
    # check cmd
    cmd = body.get('data').get('name')
    if (cmd != "vh"):
        response.content = "Invalid request: Invalid command"
        logger.error(response.content)
        sendFollowupMessage(endpointInfo, token, response)
        return -1
    
    # get the option
    opt = body.get('data').get('options')[0].get('value')
    if (opt not in VH_OPTIONS):
        response.content = "Invalid request: Invalid command option"
        logger.error(response.content)
        sendFollowupMessage(endpointInfo, token, response)
        return -1
    
    # except Exception as e:
    #     logger.error(f"Invalid request: {e}")
    #     return -1
    
    # process the command option
    logger.info(f"Received command option: {opt}")
    
    if (opt == "status"):
        return vh_status(endpointInfo, token)
    
    if (opt == "start"):
        return vh_start(endpointInfo, token)
        
    if (opt == "stop"):
        return vh_stop(endpointInfo, token)
    

###############################################################################
## TEST
if __name__ == '__main__':
    ret = lambda_handler(json.loads("""
{
    "Records": [{
        "Sns": {
            "Message": "{\"jsonBody\": {\"data\": {\"name\": \"vh\", \"options\": [{\"name\": \"valheim_server_controls\", \"type\": 3, \"value\": \"status\"}], \"type\": 1}}}"
        }
    }]
    
}
    """), "")
    print(ret)

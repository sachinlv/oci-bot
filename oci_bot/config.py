"""
Copyright @ Oracle®2024
"""
import os

class Config():
    PROMPT_TEMPLATE = """
        Answer the question only based on the following context:
            {context} Question: {question}
    """

    PROMPT_TEMPLATE_2 = """
        Answer the question:
            Question: {question}
    """

    TABLE_NAME = "INCIDENT_DATA"
    deployment_env = os.getenv("IB_DEPLOYMENT_ENV") if os.getenv("IB_DEPLOYMENT_ENV") is not None  else "dev"
    CONFIG_FILE = f"config/app_config.{deployment_env}.yml"
    CHAT_TITLE = "🦜🔗 Welcome to the Incident Bot"
    CHAT_INPUT_TAG_LINE = "Enter your query ?"
    ROLE_USER = "user" # TODO: This should be fetched from Login
    ROLE_ASSISTANT = "assistant"

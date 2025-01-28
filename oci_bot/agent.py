"""
Copyright @ Oracle®2024
"""
import logging
import os
from typing import Any
import yaml

import oracledb
import streamlit as st
from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from langchain_core.prompts import PromptTemplate, ChatPromptTemplate, HumanMessagePromptTemplate
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser
from langchain_community.chat_message_histories import StreamlitChatMessageHistory
from langchain_community.vectorstores.oraclevs import OracleVS
from langchain_community.vectorstores.utils import DistanceStrategy
from langchain_community.chat_models import ChatOCIGenAI
from langchain_community.embeddings import OCIGenAIEmbeddings

from oci_bot.config import Config


class OCIAgent:
    """Agent Class
    """
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        with open(Config.CONFIG_FILE, "r", encoding="utf-8") as config_file:
            self.config = yaml.safe_load(config_file)['OCI']
        self.llm = ChatOCIGenAI(
            model_id=self.config["AI"]["INFERENCE_MODEL"],
            service_endpoint=self.config["AI"]["SERVICE_ENDPOINT"],
            compartment_id=self.config["COMPARTMENT_OCID"],
            model_kwargs={"temperature": 0.7, "max_tokens": 400}
        )
        self.history = StreamlitChatMessageHistory(key="chat_messages")


    def generate_response(self, user_input: str) -> Any:
        """Generate response based on user input
        Args:
            user_input: User input text
        """
        self.logger.info("Generating response for the user query.")
        memory = ConversationBufferMemory(chat_memory=self.history)
        prompt = PromptTemplate.from_template(Config.PROMPT_TEMPLATE_2)

        chain = LLMChain(
            llm=self.llm,
            prompt = prompt,
            memory = memory
        )
        # chain = (
        #     {"context": self.retrieve(), "question": RunnablePassthrough()}
        #     | prompt
        #     | self.llm
        #     | StrOutputParser()
        # )
        llm_response = chain.invoke({"question": user_input})
        yield llm_response["text"]


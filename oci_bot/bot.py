"""
Copyright @ Oracle®2024
"""
import logging
import os
from typing import Any
import streamlit as st

from oci_bot.config import Config
from oci_bot.agent import OCIAgent


class Session:
    def __init__(self):
        st.title(Config.CHAT_TITLE)
        self.__load_history()
        self.agent = OCIAgent()
        self.logger = logging.getLogger("OCI_BOT")

    def __load_history(self):
        """Load chat history.
        """
        # TODO: Save the messages in REDIS or RabbitMQ.
        # TODO: Load chat history based on profiles.
        if "messages" not in st.session_state:
            st.session_state.messages = []

        # Display chat messages from history
        for message in st.session_state.messages:
            with st.chat_message(message["role"]):
                st.markdown(message["content"])


    def start(self):
        """ Chatbot session start
        """
        self.logger.info("starting chat session")
        if user_input := st.chat_input(Config.CHAT_INPUT_TAG_LINE):
            st.session_state.messages.append({"role": Config.ROLE_USER, "content": user_input})
            with st.chat_message(Config.ROLE_USER):
                st.markdown(user_input)

            with st.chat_message(Config.ROLE_ASSISTANT):
                agent_response = self.agent.generate_response(user_input)
                response = st.write_stream(agent_response)
                st.session_state.messages.append({"role": "assistant", "content": response})



if __name__ == '__main__':
    chat = Session()
    chat.start()

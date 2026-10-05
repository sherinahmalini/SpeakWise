import streamlit as st
st.title("My First Streamlit App")
st.write("Welcome to Streamlit!")
name = st.text_input("Enter Your Name")

if st.button("Submit"):
    st.success(f"Hello {name}")

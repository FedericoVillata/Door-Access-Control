import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import random
import string

def send_mail_pwd(receiver_address, stringa):
    try:
        # The mail addresses and password
        sender_address = 'sender_mail@gmail.com'
        sender_pass = 'string'
        
        # Setup the MIME
        message = MIMEMultipart()
        message['From'] = sender_address
        message['To'] = receiver_address
        message['Subject'] = 'Password Recovery'   # The subject line

        mail_content = '''Hello,
        This is a simple mail to communicate your temporary password random generated, please change ASAP: '''
        mail_content = f"{mail_content} : [{stringa}]"

        # The body and the attachments for the mail
        message.attach(MIMEText(mail_content, 'plain'))

        # Create SMTP session for sending the mail
        session = smtplib.SMTP('smtp.gmail.com', 587) # use gmail with port
        session.starttls() # enable security
        
        # Login with mail_id and password
        session.login(sender_address, sender_pass)
        
        # Convert the message to a string and send it
        text = message.as_string()
        session.sendmail(sender_address, receiver_address, text)
        session.quit()
        response = 'Mail Sent'
        rp_status = True
        
    except smtplib.SMTPException as e:
        response = f'Failed to send email: {e}'
        rp_status = False
        
    except Exception as e:
        response = f'An error occurred: {e}'
        rp_status = False
        
    return rp_status, response

def generate_password(length=12):
    characters = string.ascii_letters + string.digits + string.punctuation
    password = ''.join(random.choice(characters) for _ in range(length))
    return password

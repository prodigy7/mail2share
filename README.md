# mail2share

This simple script is used to retrieve mails from a mailbox and transfer their attachments via SAMBA to another server.

The script was developed from the situation to provide invoices in a simple way for the software ecoDMS.

## Requirements

The script was tested with Debian GNU/Linux 9. Packages needed are getmail, ripmime and curl.

Command for install in debian:
```
apt install getmail4 ripmime curl
```

## Setup

In ``conf`` you will find different template files.

### Basic configuration

The file ``fetchmails.conf.dist`` (copy to ``fetchmails.conf``) define some basic parameters:
```
POSTMASTER= <- Recipient for script error mails
SMB_USER=   <- Username for samba share
SMB_PASS=   <- Password for samba share
SMB_PATH=   <- Path for storing attachments
SMB_TYPE=   <- Could 'curl' or 'mount'
```

If ``SMB_TYPE`` is set ``mount``, the script expect that the attachment directory is a mounted directory. If checks fail, script will report and stop.
If ``SMB_TYPE`` is set ``curl``, the script will transfer files with curls.

Working with ``mount`` can handle the situation, files with same name already exists. If processing file at remote does not work, transfering files with ``curl`` could maybe overwrite existing files.

### Mailbox configuration

The file ``user.getmail.conf.dist`` (copy to ``<placeholder>.getmail.conf``) define parameters for fetching mails. You can define multiple configurations. For most parameters see http://pyropus.ca/software/getmail/configuration.html.

```
[retriever]
type=SimpleIMAPSSLRetriever         <- See link
server=                             <- See link
username=                           <- See link
password=                           <- See link
mailboxes=("INBOX.Archive",)        <- Define, where script should look for mails
move_on_delete="INBOX.Archive.Done" <- Define, where mails should moved when they are fetched

[destination]
type=Maildir
path=/opt/mail2share/mails/         <- Where mails are stored (Script base path added with /mails)

[options]
delete=true
message_log=/opt/mail2share/log/getmail.log <- Where log should written
```

## Ideal workflow

When you receive a invoice as pdf for example, you move this mail into the folder ``Archive``.  When the scripts run (for example by cron), it fetch the mail, extract the attachment and move it to the samba share. Next the mail is move to the folder ``Archive\Done``.

# It is necessary to use SSH key login, which removes the need for a password for each login, thus ensuring a password-less, automatic login process
# To do that use
# `$ ssh-keygen` to generate public and private key files stored in the ~/.ssh directory
# Then copy the public key in the ~/.ssh/authorized_keys file, on ubuntu you can use
# `ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote_host`
# or (if ssh-copy-id not installed)
# `cat ~/.ssh/id_rsa.pub | ssh username@remote_host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" `
# Eventually, for Windows users, you can manually copy your public key
# open `~/.ssh/id_rsa.pub` and copy the public key, connect to the remote server using ssh
# `echo past >> ~/.ssh/authorized_keys` with past the ssh key (Is it also possible to do it by hand with the GUI of FileZilla

# Username and host for ssh connection
# the host is the remote server name, I added the '@' for simplicity
username = "dumoulil"; host ="@baobab2.hpc.unige.ch"

# Git

## Sign by gpg key

```
gpg --list-secret-keys --keyid-format LONG
git config --global user.signingkey your_key_id
git config --global commit.gpgsign true
```

## Alias

```
git config --global alias.st status
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
```

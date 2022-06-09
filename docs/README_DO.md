3.1 Логуємося до Digital Ocean:
- переходимо в меню API, генеруємо новий токін і копіюємо його

1.
![AWS](images/do_1.jpg)

---
2.
![AWS](images/do_2.jpg)

---
3.
![AWS](images/do_3.jpg)


3.2 Відредагуємо `terraform/do/providers.tf`, де вказуємо скопійований Token замість <i>CHANGE_ME</i>:

```
provider "digitalocean" {
  token = "CHANGE_ME"
}
```

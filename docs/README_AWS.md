3.1 Логуємося до AWS Console:
- створюємо AWS IAM користувача з Administrator політикою
- зберігаємо його Access та Secret ключі

1.
![AWS](images/iam_1.png)

---
2.
![AWS](images/iam_2.png)

---
3.
![AWS](images/iam_3.png)

---
4.
![AWS](images/iam_4.png)

---
5.
![AWS](images/iam_5.png)

---
6.
![AWS](images/iam_6.png)

---


3.2 Відредагуємо `terraform/aws/providers.tf`, де вказуємо <i>access_key</i> та <i>secret_key</i> свого AWS IAM користувача замість <i>CHANGE_ME</i>:

```
provider "aws" {
  region  = local.region
  access_key = "CHANGE_ME"
  secret_key = "CHANGE_ME"
}
```

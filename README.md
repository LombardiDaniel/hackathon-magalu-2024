# hackathon-magalu-2024

```sh
exportenv() {
    export $(grep -v '^#' .env | xargs)
}
```

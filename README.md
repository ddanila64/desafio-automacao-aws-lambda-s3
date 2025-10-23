# Exemplo de Automação: AWS Lambda + S3

Este repositório/documentação descreve uma automação simples que utiliza AWS S3 e AWS Lambda. O fluxo processa arquivos enviados para um bucket de entrada, transforma o conteúdo e grava o resultado em um bucket de saída. Ao final, a função Lambda pode notificar via SNS ou SES que o processamento foi concluído.

## Fluxo resumido
1. Usuário envia um arquivo para o bucket S3 (`meu-bucket-entrada`).
2. Evento do S3 dispara automaticamente uma AWS Lambda Function.
3. Lambda processa o arquivo:
   - lê o conteúdo do arquivo;
   - transforma ou extrai dados;
   - gera um novo arquivo de resultado.
4. O resultado é salvo em outro bucket (`meu-bucket-saida`).
5. Lambda envia notificação (opcional) via SNS ou SES informando que o processo terminou.

## Arquitetura
- S3 (meu-bucket-entrada) → evento "ObjectCreated" → Lambda (Python 3.12)
- Lambda faz leitura do objeto, processa e grava em S3 (meu-bucket-saida)
- Lambda publica mensagem em SNS (ou envia e-mail via SES) notificando o término

Exemplo simplificado:
```
meu-bucket-entrada (S3)
         |
  ObjectCreated -> Lambda (Python 3.12)
         |
  processa arquivo -> meu-bucket-saida/processed/
         |
  publica notificação -> SNS / SES (opcional)
```

## Pré-requisitos
- Conta AWS com permissões para:
  - S3 (criar buckets, ler/gravá-los)
  - IAM (criar role para Lambda)
  - Lambda (criar função)
  - SNS/SES (opcional, para notificações)
- AWS CLI configurado localmente (opcional, para testes)
- Python 3.12 (runtime Lambda)

## Passos para configurar

1. Crie dois buckets S3:
   - meu-bucket-entrada
   - meu-bucket-saida

2. Crie uma Role do IAM para a Lambda com as permissões necessárias (exemplo de policy abaixo).

3. Crie a função Lambda:
   - Runtime: Python 3.12
   - Handler: lambda_function.lambda_handler (ou conforme nome do arquivo)
   - Atribua a Role do IAM criada no passo 2.
   - Aumente o timeout se necessário (padrão 3s pode ser insuficiente).

4. Configure o gatilho (trigger) no bucket `meu-bucket-entrada`:
   - No Console S3 → selecione o bucket → aba "Propriedades" → "Eventos" → "Criar evento".
   - Evento: "PUT" / "Criar objeto" (ObjectCreated)
   - Destino: a função Lambda criada.

5. Faça o deploy do código da Lambda (ex.: via console, AWS CLI, SAM ou Terraform).

6. Teste:
   - Envie um arquivo `.txt` para `meu-bucket-entrada` e verifique a existência do arquivo processado em `meu-bucket-saida/processed/`.

## Código de exemplo (handler Lambda — Python)
```python
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Pega informações do arquivo enviado
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    
    print(f"Arquivo recebido: {file_key} no bucket {bucket_name}")
    
    # Faz download do arquivo
    local_path = f"/tmp/{os.path.basename(file_key)}"
    s3.download_file(bucket_name, file_key, local_path)

    # Processamento simples — por exemplo, ler o conteúdo e modificar
    with open(local_path, "r") as f:
        conteudo = f.read().upper()  # transforma em maiúsculas

    # Cria novo arquivo
    new_file = f"/tmp/processed_{os.path.basename(file_key)}"
    with open(new_file, "w") as f:
        f.write(conteudo)

    # Envia para bucket de saída
    output_bucket = "meu-bucket-saida"
    s3.upload_file(new_file, output_bucket, f"processed/{os.path.basename(new_file)}")

    print(f"Arquivo processado salvo em: s3://{output_bucket}/processed/{os.path.basename(new_file)}")

    return {
        "statusCode": 200,
        "body": f"Processado: {file_key}"
    }
```

Observações:
- A Lambda usa o diretório /tmp para operações de E/S locais (limite ~512 MB).
- Ajuste tratamento de erros, logs e encoding conforme necessário.
- Se arquivos maiores forem esperados, considere streaming ou processamento por partes.

## Permissões IAM mínimas (exemplo)
Anexe esta policy (ou equivalente) à role da Lambda para permitir S3 e publicação em SNS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::meu-bucket-entrada",
        "arn:aws:s3:::meu-bucket-entrada/*",
        "arn:aws:s3:::meu-bucket-saida",
        "arn:aws:s3:::meu-bucket-saida/*"
      ]
    },
    {
      "Sid": "SNSPublish",
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "arn:aws:sns:REGIAO:ACCOUNT_ID:SEU_TOPICO_SNS"
      ]
    }
  ]
}
```

Substitua `REGIAO`, `ACCOUNT_ID` e `SEU_TOPICO_SNS` pelos valores reais. Se usar SES, será necessário adicionar as permissões SES correspondentes.

## Envio de notificação (exemplo rápido usando SNS)
```python
import boto3

sns = boto3.client('sns')

def notify_sns(topic_arn, message, subject=None):
    sns.publish(
        TopicArn=topic_arn,
        Message=message,
        Subject=subject or "Processamento Concluído"
    )
```

Dentro do seu handler, chame:
```python
notify_sns("arn:aws:sns:REGIAO:ACCOUNT_ID:SEU_TOPICO_SNS", f"Arquivo {file_key} processado com sucesso.")
```

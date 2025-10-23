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

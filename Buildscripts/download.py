from http import HTTPStatus, client
import os
import shutil

MODELS = [
    'CenterFace',
    'FaceMesh',

    'Bryan_Greynolds',
    'David_Kovalniy',
    'Ewon_Spice',
    'Kim_Jarrey',
    'Tim_Chrys',
    'Tim_Norland',
    'Zahar_Lupin'
]

BASE_URL = 'ml.facade.gg'

if __name__ == "__main__":
    os.makedirs('/opt/facade', exist_ok=True)

    files = [
        f'{model}/{model}.onnx' for model in MODELS
    ] + [
        f'{model}/{model}.mlmodel' for model in MODELS
    ]

    for file in files:
        if os.path.exists(f'/opt/facade/{os.path.basename(file)}'):
            print(f'https://{BASE_URL}/{file} was already downloaded')
            continue

        connection = client.HTTPSConnection(BASE_URL)

        print(f'Downloading https://{BASE_URL}/{file}')
        connection.request('GET', f'/{file}') 

        with connection.getresponse() as response:
            if response.status == HTTPStatus.OK:
                shutil.copyfileobj(response, open(f'/opt/facade/{os.path.basename(file)}', 'b+w'))
            else:
                raise Exception(f'Failed to download file ({response.status})')
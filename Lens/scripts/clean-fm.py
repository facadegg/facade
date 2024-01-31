import onnx
import numpy as np


def find_node_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.node if x.name == name][0]


def find_initializer_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.initializer if x.name == name][0]


if __name__ == "__main__":
    model = onnx.load('/opt/facade/FaceMesh-old.onnx')
    surgery = [
        find_node_by_name('channel_padding_1', model),
        find_node_by_name('channel_padding_2', model),
        find_node_by_name('channel_padding_3', model),
    ]
    sizes = [48, 24, 12]

    for line_idx, node in enumerate(surgery):
        pads = node.attribute[0]

        channels = pads.ints[-3]
        size = sizes[line_idx]
        print(f"channels {channels} size {size}")

        model.graph.initializer.append(onnx.TensorProto(name=f'{node.name}-pad-concat',
                                                        dims=[1, channels, size, size],
                                                        data_type=onnx.TensorProto.FLOAT,
                                                        float_data=np.zeros([channels * size * size]).tolist()))
        node.CopyFrom(onnx.NodeProto(name=node.name,
                                     input=[node.input[0],
                                            f'{node.name}-pad-concat'],
                                     output=node.output,
                                     attribute=[
                                         onnx.AttributeProto(name='axis',
                                                             i=-3,
                                                             type=onnx.AttributeProto.INT)
                                     ],
                                     op_type='Concat'))

    model.opset_import.pop()
    model.opset_import.append(onnx.OperatorSetIdProto(domain="ai.onnx", version=11))
    onnx.save(model, '/opt/facade/FaceMesh.onnx')
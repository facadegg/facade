import onnx
import re


def find_node_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.node if x.name == name][0]


def find_initializer_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.initializer if x.name == name][0]


if __name__ == "__main__":
    model = onnx.load('/opt/facade/CenterFace-vold.onnx')

    actual_input = model.graph.input[0].name
    actual_first_node = model.graph.node[0]
    actual_first_node.input[0] = 'interim'
    model.graph.node.insert(0, onnx.NodeProto(name='prepare-with-tranpose',
                                              input=[actual_input],
                                              output=['interim'],
                                              op_type='Transpose',
                                              attribute=[
                                                  # 1x480x640x3 to 1x3x480x640
                                                  onnx.AttributeProto(name='perm',
                                                                      ints=[0, 3, 1, 2],
                                                                      type=onnx.AttributeProto.INTS)
                                              ]))
    model.graph.input[0].CopyFrom(onnx.ValueInfoProto(name=actual_input,
                                                      type=onnx.TypeProto(tensor_type=onnx.TypeProto.Tensor(elem_type=onnx.TensorProto.FLOAT,
                                                                                                            shape=onnx.TensorShapeProto(dim=[
                                                                                                                onnx.TensorShapeProto.Dimension(dim_value=1),
                                                                                                                onnx.TensorShapeProto.Dimension(dim_value=480),
                                                                                                                onnx.TensorShapeProto.Dimension(dim_value=640),
                                                                                                                onnx.TensorShapeProto.Dimension(dim_value=3)
                                                                                                            ])))))

    onnx.save(model, '/opt/facade/CenterFace.onnx')

#include <cassert>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#include "mesh.h"

static mesh_t *
build_mesh_t(std::vector<glm::vec3> positions, std::vector<glm::vec2> texcoords,
             std::vector<glm::vec3> normals, std::vector<glm::vec4> tangents,
             std::vector<glm::vec4> joints, std::vector<glm::vec4> weights,
             std::vector<int> position_indices,
             std::vector<int> texcoord_indices,
             std::vector<int> normal_indices) {

  int num_indices = position_indices.size();
  int num_faces = num_indices / 3;
  std::vector<vertex_t> vertices(num_indices);
  mesh_t *mesh = new mesh_t();

  assert(num_faces > 0 && num_faces * 3 == num_indices);
  assert(position_indices.size() == num_indices);
  assert(texcoord_indices.size() == num_indices);
  assert(normal_indices.size() == num_indices);

  for (int i = 0; i < num_indices; i++) {
    int position_index = position_indices[i];
    int texcoord_index = texcoord_indices[i];
    int normal_index = normal_indices[i];
    assert(position_index >= 0 && position_index < positions.size());
    assert(texcoord_index >= 0 && texcoord_index < texcoords.size());
    assert(normal_index >= 0 && normal_index < normals.size());
    vertices[i].position = positions[position_index];
    vertices[i].texcoord = texcoords[texcoord_index];
    vertices[i].normal = normals[normal_index];

    if (tangents.size() != 0) {
      int tangent_index = position_index;
      assert(tangent_index >= 0 && tangent_index < tangents.size());
      vertices[i].tangent = tangents[tangent_index];
    } else {
      vertices[i].tangent = glm::vec4(1, 0, 0, 1);
    }

    if (joints.size() != 0) {
      int joint_index = position_index;
      assert(joint_index >= 0 && joint_index < joints.size());
      vertices[i].joint = joints[joint_index];
    } else {
      vertices[i].joint = glm::vec4(0, 0, 0, 0);
    }

    if (weights.size() != 0) {
      int weight_index = position_index;
      assert(weight_index >= 0 && weight_index < weights.size());
      vertices[i].weight = weights[weight_index];
    } else {
      vertices[i].weight = glm::vec4(0, 0, 0, 0);
    }
  }

  mesh->num_faces = num_faces;
  mesh->vertices = vertices;

  return mesh;
}

static mesh_t *load_obj(std::string filename) {
  std::vector<glm::vec3> positions;
  std::vector<glm::vec2> texcoords;
  std::vector<glm::vec3> normals;
  std::vector<glm::vec4> tangents;
  std::vector<glm::vec4> joints;
  std::vector<glm::vec4> weights;
  std::vector<int> position_indices;
  std::vector<int> texcoord_indices;
  std::vector<int> normal_indices;
  char line[256];
  mesh_t *mesh;
  FILE *file;

  file = fopen(filename.c_str(), "rb");
  assert(file != NULL);
  while (1) {
    int items;
    if (fgets(line, 256, file) == NULL) {
      break;
    } else if (strncmp(line, "v ", 2) == 0) { /* position */
      glm::vec3 position;
      items = sscanf(line, "v %f %f %f", &position.x, &position.y, &position.z);
      assert(items == 3);
      positions.push_back(position);
    } else if (strncmp(line, "vt ", 3) == 0) { /* texcoord */
      glm::vec2 texcoord;
      items = sscanf(line, "vt %f %f", &texcoord.x, &texcoord.y);
      assert(items == 2);
      texcoords.push_back(texcoord);
    } else if (strncmp(line, "vn ", 3) == 0) { /* normal */
      glm::vec3 normal;
      items = sscanf(line, "vn %f %f %f", &normal.x, &normal.y, &normal.z);
      assert(items == 3);
      normals.push_back(normal);
    } else if (strncmp(line, "f ", 2) == 0) { /* face */
      int i;
      int pos_indices[3], uv_indices[3], n_indices[3];
      items =
          sscanf(line, "f %d/%d/%d %d/%d/%d %d/%d/%d", &pos_indices[0],
                 &uv_indices[0], &n_indices[0], &pos_indices[1], &uv_indices[1],
                 &n_indices[1], &pos_indices[2], &uv_indices[2], &n_indices[2]);
      assert(items == 9);
      for (i = 0; i < 3; i++) {
        position_indices.push_back(pos_indices[i] - 1);
        texcoord_indices.push_back(uv_indices[i] - 1);
        normal_indices.push_back(n_indices[i] - 1);
      }
    } else if (strncmp(line, "# ext.tangent ", 14) == 0) { /* tangent */
      glm::vec4 tangent;
      items = sscanf(line, "# ext.tangent %f %f %f %f", &tangent.x, &tangent.y,
                     &tangent.z, &tangent.w);
      assert(items == 4);
      tangents.push_back(tangent);
    } else if (strncmp(line, "# ext.joint ", 12) == 0) { /* joint */
      glm::vec4 joint;
      items = sscanf(line, "# ext.joint %f %f %f %f", &joint.x, &joint.y,
                     &joint.z, &joint.w);
      assert(items == 4);
      joints.push_back(joint);
    } else if (strncmp(line, "# ext.weight ", 13) == 0) { /* weight */
      glm::vec4 weight;
      items = sscanf(line, "# ext.weight %f %f %f %f", &weight.x, &weight.y,
                     &weight.z, &weight.w);
      assert(items == 4);
      weights.push_back(weight);
    }
  }
  fclose(file);

  mesh = build_mesh_t(positions, texcoords, normals, tangents, joints, weights,
                      position_indices, texcoord_indices, normal_indices);

  return mesh;
}

mesh_t *load_mesh(std::string filename) {
  std::string extension = "";
  size_t last_dot = filename.find_last_of('.');
  if (last_dot != std::string::npos) {
    extension = filename.substr(last_dot + 1);
  }
  if (extension == "obj")
    return load_obj(filename);
  else {
    assert(0);
    return NULL;
  }
}
